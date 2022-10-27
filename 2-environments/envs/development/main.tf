/**
 * Copyright 2021 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

module "env" {
  # If you add more folders in source structure make sure to check:
  # - modules sources
  # - tfvars symbolic links
  source = "../../modules/env_baseline"

  env                        = "dev"
  environment_code           = "d"
  monitoring_workspace_users = var.monitoring_workspace_users
  remote_state_bucket        = var.remote_state_bucket

  new_parent_folder = google_folder.finance.name
}

# Create folder hierarchy
resource "google_folder" "finance" {
  display_name = "finance"
  parent       = data.terraform_remote_state.bootstrap.outputs.common_config.parent_id
}

# Get bootstrap state for parent_folder
data "terraform_remote_state" "bootstrap" {
  backend = "gcs"

  config = {
    bucket = var.remote_state_bucket
    prefix = "terraform/bootstrap/state"
  }
}
