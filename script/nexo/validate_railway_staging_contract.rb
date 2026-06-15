#!/usr/bin/env ruby

require 'json'

contract_path = ARGV.fetch(0)
repo_root = File.expand_path('../..', __dir__)
contract = JSON.parse(File.read(contract_path))
errors = []

expected_project_id = '93404cd1-0fc9-4a0f-9319-722685cc81f0'
expected_environment_id = '27ca71ff-726f-4f76-8117-506bc5a62ca4'
expected_digest = '8576d9d3a9535a59fc729ea6c9394ab7a3bd70de9a1f8d3eac947a3daaa86d30'
expected_web_id = 'ce724e5a-2231-4732-a19f-bf6654a0d6bd'
expected_worker_id = '96da393f-2a16-4cf9-93ac-bb48d0926456'
expected_postgres_id = 'b89dbdad-1346-47b3-984a-2ab37d14f693'
expected_valkey_id = '9be11a8b-66e2-4867-8050-878ea3fdfa49'
expected_bucket_id = '962dfe27-7de4-47e1-ad11-0e3b32a0c540'
chatwoot_version = File.read(File.join(repo_root, 'VERSION_CW')).strip
nexo_version = File.read(File.join(repo_root, 'VERSION_NEXO')).strip
expected_image = "ghcr.io/eliseoci/chatwoot-pipelines:v#{nexo_version}@sha256:#{expected_digest}"

target = contract.fetch('target', {})
release = contract.fetch('release', {})
services = contract.fetch('services', {})
safety = contract.fetch('safety', {})
variables = contract.fetch('application_variables', {})

errors << 'schema_version must be 1' unless contract['schema_version'] == 1
errors << 'contract must record completed staging verification' unless contract['status'] == 'provisioned_and_verified'
errors << 'environment must be staging' unless contract['environment'] == 'staging'
errors << 'target project does not match the confirmed staging project' unless target['project_id'] == expected_project_id
errors << 'target environment does not match the confirmed staging environment' unless target['environment_id'] == expected_environment_id
errors << 'expected environment name must be staging' unless target['expected_environment_name'] == 'staging'
errors << 'explicit target confirmation must remain required' unless target['requires_explicit_target_confirmation'] == true
errors << 'production mutation must remain forbidden' unless target['production_mutation_allowed'] == false

errors << 'Chatwoot version does not match VERSION_CW' unless release['chatwoot_version'] == chatwoot_version
errors << 'Nexo version does not match VERSION_NEXO' unless release['nexo_version'] == nexo_version
errors << 'release image must use the published immutable image' unless release['image'] == expected_image
errors << 'release image must not use latest' if release.fetch('image', '').include?(':latest')
errors << 'migration command is not the approved single-run command' unless release['migration_command'] == 'POSTGRES_STATEMENT_TIMEOUT=600s bundle exec rails db:chatwoot_prepare'
errors << 'Railway migration command must expand the environment assignment through a shell' unless release['railway_migration_command'] == "/bin/sh -lc 'POSTGRES_STATEMENT_TIMEOUT=600s bundle exec rails db:chatwoot_prepare'"
errors << 'migration must run once before application start' unless release['migration_execution'] == 'single_run_before_app_start'

web = services.fetch('web', {})
worker = services.fetch('worker', {})
postgres = services.fetch('postgres', {})
valkey = services.fetch('valkey', {})
object_storage = services.fetch('object_storage', {})

errors << 'Web and Worker must be separate services' if web['name'] == worker['name']
errors << 'Web service ID does not match staging' unless web['id'] == expected_web_id
errors << 'Worker service ID does not match staging' unless worker['id'] == expected_worker_id
errors << 'Postgres service ID does not match staging' unless postgres['id'] == expected_postgres_id
errors << 'Valkey service ID does not match staging' unless valkey['id'] == expected_valkey_id
errors << 'Bucket ID does not match staging' unless object_storage['id'] == expected_bucket_id
[web, worker].each do |service|
  errors << "#{service['name'] || 'application'} must use the immutable release image" unless service['image'] == expected_image
  errors << "#{service['name'] || 'application'} must not have a persistent volume" unless service['persistent_volume'] == false
  errors << "#{service['name'] || 'application'} must restart always" unless service['restart_policy'] == 'ALWAYS'
end

errors << 'Web start command must expand Railway PORT through a shell' unless web['start_command'] == "/bin/sh -lc 'bundle exec rails server -p \"$PORT\" -b 0.0.0.0'"
errors << 'Web must use the native /health HTTP healthcheck' unless web.dig('healthcheck', 'type') == 'http' && web.dig('healthcheck', 'path') == '/health'
errors << 'Worker start command is incorrect' unless worker['start_command'] == 'bundle exec sidekiq -C config/sidekiq.yml'
errors << 'Worker must use process/log health rather than a fake HTTP endpoint' unless worker.dig('healthcheck', 'type') == 'process_and_logs' && worker.dig('healthcheck', 'http_path').nil?
errors << 'Worker must define an operational Sidekiq probe' unless worker.dig('healthcheck', 'operational_probe').to_s.include?('Sidekiq::ProcessSet')

errors << 'Postgres must remain on major version 16' unless postgres['major_version'] == 16
errors << 'Postgres must use a pg16 image' unless postgres.fetch('image', '').end_with?('pg16')
errors << 'Postgres data path is incorrect' unless postgres['persistent_volume_path'] == '/var/lib/postgresql/data'
errors << 'Valkey must use the pinned major-8 alpine image' unless valkey['image'] == 'valkey/valkey:8-alpine'
errors << 'Valkey data path is incorrect' unless valkey['persistent_volume_path'] == '/data'
errors << 'Valkey must use one stable secret written once' unless valkey['credential_strategy'] == 'one_stable_secret_written_via_stdin'
errors << 'Object storage must be a Railway bucket' unless object_storage['type'] == 'railway_bucket'
errors << 'Application services must use object storage rather than a shared volume' unless object_storage['persistent_volume'] == false

required_variables = {
  'RAILS_ENV' => 'production',
  'RAILS_LOG_TO_STDOUT' => 'true',
  'NODE_ENV' => 'production',
  'DATABASE_URL' => '${{Postgres.DATABASE_URL}}',
  'REDIS_URL' => '<set-via-stdin:stable-private-valkey-url>',
  'ACTIVE_STORAGE_SERVICE' => 's3_compatible',
  'ENABLE_ACCOUNT_SIGNUP' => 'false',
  'STORAGE_FORCE_PATH_STYLE' => 'false'
}
required_variables.each do |key, value|
  errors << "#{key} must equal #{value}" unless variables[key] == value
end

reference_variables = %w[
  DATABASE_URL
  SECRET_KEY_BASE
  STORAGE_ACCESS_KEY_ID
  STORAGE_SECRET_ACCESS_KEY
  STORAGE_REGION
  STORAGE_BUCKET_NAME
  STORAGE_ENDPOINT
]
reference_variables.each do |key|
  value = variables[key].to_s
  errors << "#{key} must use a Railway reference or generated secret" unless value.match?(/\A.*\$\{\{(?:secret\(\d+\)|[A-Za-z0-9_-]+\.[A-Za-z0-9_]+)\}\}.*\z/)
end

required_safety = {
  'fresh_or_synthetic_data_only' => true,
  'production_domain_attached' => false,
  'production_webhooks_enabled' => false,
  'smtp_enabled' => false,
  'customer_channel_credentials_present' => false,
  'worker_started_after_migration' => true,
  'production_service_ids_referenced' => false,
  'legacy_shared_staging_services_mutated' => false
}
required_safety.each do |key, value|
  errors << "safety.#{key} must remain #{value}" unless safety[key] == value
end

verification = contract.fetch('verification', {})
errors << 'backup restoration must be verified' unless verification['backup_restore_verified'] == true
errors << 'all Pipeline migrations must be recorded' unless verification['pipeline_migration_count'] == 12
errors << 'post-migration count must include all Pipeline migrations' unless verification['post_migration_count'] == verification['pre_migration_count'].to_i + 12
errors << 'object-storage smoke verification is missing' unless verification['storage_upload_read_delete_verified'] == true
errors << 'Pipeline/conversation smoke verification is missing' unless verification['pipeline_conversation_smoke_verified'] == true
errors << 'synthetic records must be rolled back' unless verification['synthetic_records_rolled_back'] == true
errors << 'image roll-forward verification is missing' unless verification['rollforward_verified'] == true

if errors.any?
  warn "Railway staging contract validation failed:\n- #{errors.join("\n- ")}"
  exit 1
end

puts "Railway staging contract is valid for #{expected_image}"
