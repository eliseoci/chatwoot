#!/usr/bin/env ruby

require 'json'

contract_path = ARGV.fetch(0)
repo_root = File.expand_path('../..', __dir__)
contract = JSON.parse(File.read(contract_path))
errors = []

expected_template_id = 'b506e365-4d5f-42d4-97ce-e66dba3404ff'
expected_template_code = 'nexo-chatwoot-pipelines'
expected_template_url = 'https://railway.com/deploy/nexo-chatwoot-pipelines'
expected_source_project_id = 'f501f9bf-f945-456c-84eb-bf3e183622a1'
expected_source_environment_id = '1f31560b-937a-4dac-8cab-2b7b52454859'
expected_smoke_project_id = 'd8f3be3d-e429-4652-b56e-aca7c8c65637'
expected_smoke_environment_id = '55e2e41d-e831-4198-837d-f8a7c0a4d353'
expected_digest = '8576d9d3a9535a59fc729ea6c9394ab7a3bd70de9a1f8d3eac947a3daaa86d30'
chatwoot_version = File.read(File.join(repo_root, 'VERSION_CW')).strip
nexo_version = File.read(File.join(repo_root, 'VERSION_NEXO')).strip
expected_image = "ghcr.io/eliseoci/chatwoot-pipelines:v#{nexo_version}@sha256:#{expected_digest}"

template = contract.fetch('template', {})
release = contract.fetch('release', {})
source_project = contract.fetch('source_project', {})
smoke_project = contract.fetch('smoke_project', {})
services = contract.fetch('services', {})
requirements = contract.fetch('serialized_config_requirements', {})
cli_limitation = contract.fetch('railway_cli_limitation', {})
verification = contract.fetch('verification', {})

errors << 'schema_version must be 1' unless contract['schema_version'] == 1
errors << 'template contract must be published and smoke verified' unless contract['status'] == 'published_and_smoke_verified'

errors << 'template ID changed' unless template['id'] == expected_template_id
errors << 'template code changed' unless template['code'] == expected_template_code
errors << 'template URL changed' unless template['url'] == expected_template_url
errors << 'template must remain published' unless template['status'] == 'PUBLISHED'
errors << 'template category must remain Automation' unless template['category'] == 'Automation'

errors << 'Chatwoot version does not match VERSION_CW' unless release['chatwoot_version'] == chatwoot_version
errors << 'Nexo version does not match VERSION_NEXO' unless release['nexo_version'] == nexo_version
errors << 'release image must use the published immutable image' unless release['image'] == expected_image
errors << 'release image must not use latest' if release.fetch('image', '').include?(':latest')
errors << 'migration command is not the approved single-run command' unless release['migration_command'] == 'POSTGRES_STATEMENT_TIMEOUT=600s bundle exec rails db:chatwoot_prepare'
errors << 'Railway migration command must expand the environment assignment through a shell' unless release['railway_migration_command'] == "/bin/sh -lc 'POSTGRES_STATEMENT_TIMEOUT=600s bundle exec rails db:chatwoot_prepare'"
errors << 'migration must run before Web start' unless release['migration_execution'] == 'single_run_before_web_start'

errors << 'source project ID changed' unless source_project['project_id'] == expected_source_project_id
errors << 'source environment ID changed' unless source_project['environment_id'] == expected_source_environment_id
errors << 'source environment must be template' unless source_project['environment_name'] == 'template'
errors << 'source health response must be Chatwoot health JSON' unless source_project['verified_health_response'] == '{"status":"woot"}'

errors << 'smoke project ID changed' unless smoke_project['project_id'] == expected_smoke_project_id
errors << 'smoke environment ID changed' unless smoke_project['environment_id'] == expected_smoke_environment_id
errors << 'smoke health response must be Chatwoot health JSON' unless smoke_project['verified_health_response'] == '{"status":"woot"}'

web = services.fetch('web', {})
worker = services.fetch('worker', {})
postgres = services.fetch('postgres', {})
valkey = services.fetch('valkey', {})
object_storage = services.fetch('object_storage', {})

[web, worker].each do |service|
  errors << "#{service['name'] || 'application'} must use the immutable release image" unless service['image'] == expected_image
  errors << "#{service['name'] || 'application'} must not have a persistent volume" unless service['persistent_volume'] == false
  errors << "#{service['name'] || 'application'} must restart always" unless service['restart_policy'] == 'ALWAYS'
end

errors << 'Web and Worker must remain separate services' if web['name'] == worker['name']
errors << 'Web start command must expand Railway PORT through a shell' unless web['start_command'] == "/bin/sh -lc 'bundle exec rails server -p \"$PORT\" -b 0.0.0.0'"
errors << 'Web predeploy command must run Chatwoot prepare once' unless web['predeploy_command'] == "/bin/sh -lc 'POSTGRES_STATEMENT_TIMEOUT=600s bundle exec rails db:chatwoot_prepare'"
errors << 'Web healthcheck path must be /health' unless web['healthcheck_path'] == '/health'
errors << 'Web must be the public service' unless web['public_domain_required'] == true
errors << 'Worker start command is incorrect' unless worker['start_command'] == 'bundle exec sidekiq -C config/sidekiq.yml'

errors << 'Postgres must remain on major version 16' unless postgres['major_version'] == 16
errors << 'Postgres must use the pgvector pg16 image' unless postgres['image'] == 'pgvector/pgvector:pg16'
errors << 'Postgres data path is incorrect' unless postgres['persistent_volume_path'] == '/var/lib/postgresql/data'
errors << 'Postgres must not expose public networking' unless postgres['public_networking'] == false
errors << 'Valkey must use the pinned major-8 alpine image' unless valkey['image'] == 'valkey/valkey:8-alpine'
errors << 'Valkey data path is incorrect' unless valkey['persistent_volume_path'] == '/data'
errors << 'Valkey must not expose public networking' unless valkey['public_networking'] == false
errors << 'Object storage must be a Railway bucket' unless object_storage['type'] == 'railway_bucket'
errors << 'Object storage must not be represented as an application volume' unless object_storage['persistent_volume'] == false
errors << 'Object storage bucket must remain private' unless object_storage['public_bucket'] == false

required_requirements = {
  'must_include_buckets' => true,
  'must_include_service_volume_mounts' => true,
  'must_include_web_predeploy_command' => true,
  'must_include_restart_policy' => true,
  'must_hydrate_default_values_before_direct_api_deploy' => true
}
required_requirements.each do |key, value|
  errors << "serialized_config_requirements.#{key} must remain #{value}" unless requirements[key] == value
end

errors << 'CLI limitation must record the observed CLI version' unless cli_limitation['observed_with_cli_version'].to_s.match?(/\A5\./)
errors << 'CLI template deploy must not be marked as full V2 compatible' unless cli_limitation['cli_deploy_template_supported_for_full_v2_contract'] == false
%w[buckets preDeployCommand restartPolicyType].each do |dropped_field|
  errors << "CLI limitation must mention dropped #{dropped_field}" unless cli_limitation['reason'].to_s.include?(dropped_field)
end
errors << 'safe deploy path must mention templateDeployV2' unless cli_limitation['safe_deploy_path'].to_s.include?('templateDeployV2')

required_verification = {
  'published_template_search_verified' => true,
  'source_project_health_verified' => true,
  'smoke_project_health_verified' => true,
  'web_predeploy_preserved_in_smoke_manifest' => true,
  'web_worker_postgres_valkey_success' => true,
  'bucket_created' => true,
  'storage_upload_read_delete_verified' => true,
  'worker_sidekiq_alive_started' => true,
  'worker_scheduled_job_performed' => true,
  'valkey_authenticated_connection_verified_by_worker' => true,
  'production_project_mutated' => false
}
required_verification.each do |key, value|
  errors << "verification.#{key} must remain #{value}" unless verification[key] == value
end

if errors.any?
  warn "Railway template contract validation failed:\n- #{errors.join("\n- ")}"
  exit 1
end

puts "Railway template contract is valid for #{expected_template_url}"
