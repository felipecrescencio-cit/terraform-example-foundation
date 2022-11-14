# Guidance for modifications of resource hierarchy

This guide explains the instructions to change resource hierarchy during Terraform Foundation Example blueprint deployment.

The current deployment scenario of Terraform Foundation Example blueprint considers a flat resource hierarchy where all folders are at same level and having one folder for each environment. Here is a detailed explanation of each folder:

| Folder | Description |
| --- | --- |
| bootstrap | Contains the seed and CI/CD projects that are used to deploy foundation components. |
| common | Contains projects with cloud resources used by the organization. |
| production | Environment folder that contains projects with cloud resources that have been promoted into production. |
| non-production | Environment folder that contains a replica of the production environment to let you test workloads before you put them into production. |
| development | Environment folder that is used as a development and sandbox environment. |

This document covers two additional scenarios:

- Environment folders as root of folders hierarchy
- Environment folders as leaf of folders hierarchy

Option 1

| Current Scenario | Environment folders as root | Environment folders as leaf |
| --- | --- | --- |
| <pre>example-organization/<br>├── fldr-bootstrap<br>├── fldr-common<br>├── <b>fldr-development *</b><br>├── <b>fldr-non-production *</b><br>└── <b>fldr-production *</b><br></pre> | <pre>example-organization/<br>├── fldr-bootstrap<br>├── fldr-common<br>├── <b>fldr-development *</b><br>│   ├── finance<br>│   └── retail<br>├── <b>fldr-non-production *</b><br>│   ├── finance<br>│   └── retail<br>└── <b>fldr-production *</b><br>    ├── finance<br>    └── retail<br></pre> | <pre>example-organization/<br>├── fldr-bootstrap<br>├── fldr-common<br>├── finance<br>│   ├── <b>fldr-development *</b><br>│   ├── <b>fldr-non-production *</b><br>│   └── <b>fldr-production *</b><br>└── retail<br>    ├── <b>fldr-development *</b><br>    ├── <b>fldr-non-production *</b><br>    └── <b>fldr-production *</b></pre> |


Option 2

<table>
<thead>
<tr >
<th style="text-align: center;">
Current Scenario
</th>
<th style="text-align: center;">
Environment folders as root
</th>
<th style="text-align: center;">
Environment folders as leaf
</th>
</tr>
</thead>
<tbody>
<tr>
<td style="font-family: monospace;">
example-organization/<br>
├── fldr-bootstrap<br>
├── fldr-common<br>
├── <b>fldr-development</b><br>
├── <b>fldr-non-production</b><br>
└── <b>fldr-production</b><br>
</td>
<td style="font-family: monospace;">
example-organization/<br>
├── fldr-bootstrap<br>
├── fldr-common<br>
├── <b>fldr-development</b><br>
│&nbsp;&nbsp;&nbsp;├── finance<br>
│&nbsp;&nbsp;&nbsp;└── retail<br>
├── <b>fldr-non-production</b><br>
│&nbsp;&nbsp;&nbsp;├── finance<br>
│&nbsp;&nbsp;&nbsp;└── retail<br>
└── <b>fldr-production</b><br>
&nbsp;&nbsp;&nbsp;&nbsp;├── finance<br>
&nbsp;&nbsp;&nbsp;&nbsp;└── retail<br>
</td>
<td style="font-family: monospace;">
example-organization/<br>
├── fldr-bootstrap<br>
├── fldr-common<br>
├── finance</b><br>
│&nbsp;&nbsp;&nbsp;├── <b>fldr-development</b><br>
│&nbsp;&nbsp;&nbsp;├── <b>fldr-non-production</b><br>
│&nbsp;&nbsp;&nbsp;└── <b>fldr-production</b><br>
└── retail</b><br>
&nbsp;&nbsp;&nbsp;&nbsp;├── <b>fldr-development</b><br>
&nbsp;&nbsp;&nbsp;&nbsp;├── <b>fldr-non-production</b><br>
&nbsp;&nbsp;&nbsp;&nbsp;└── <b>fldr-production</b><br>
</td>
</tr>
</tbody>
</table>

## Code Changes - Both Scenarios

### Build Files

Review the `tf-wrapper.sh`. It is a bash script helper responsible for applying  terraform configurations for Terraform Foundation Example blueprint. The `tf-wrapper.sh` script works based on the current branch (see [Branching strategy](../README.md#branching-strategy)) and searches for a folder in the source code where name matches the current branch name. When it finds a folder it applies the terraform configurations. These changes below will make `tf-wrapper.sh` capable of searching deeper for matching folders and complying with your source code folder hierarchy.

1. Create a new variable maxdepth to set how many source folder levels should be searched for terraform configurations.

    ```text
    ...
    tmp_plan="${base_dir}/tmp_plan"
    environments_regex="^(development|non-production|production|shared)$"

    # Create maxdepth variable
    maxdepth=2  #🟢 Must be configured base in your directory design

    #🟢 Create component temp variables
    current_component=""
    old_component=""

    ## Terraform apply for single environment.
    tf_apply() {
    ...
    ```

1. Change find commands to use maxdepth variable on all terraform commands. Make sure you do the same changes in functions: `tf_plan_validate_all` and `single_action_runner`.

    ```text
    tf_plan_validate_all() {
    local env
    ...
    #🟢 Set maxdepth in find command -------------- 🟢
    find "$component_path" -mindepth 1 -maxdepth $maxdepth -type d | while read -r env_path ; do
        env="$(basename "$env_path")"
    ```

1. Add validation to check your new folder hierarchy and find terraform config files.

    ```text
     if [[ "$env" =~ $environments_regex ]] ; then
       local component_tf_arg
       # Additional validation to get source folder hierarchy and find terraform configs
       if [[ "$env_path" =~ ^($base_dir)/($component)/(.+)/$env ]] ; then
    ```

1. Set a new component name to be used as terraform plan json filenames and set it as terraform commands parameters.

    ```text
           # Set a new component name to be used as terraform plan json file names
           component_tf_arg=$(echo ${BASH_REMATCH[3]} | sed -r 's/\//__/g')
       else
           component_tf_arg=$component
       fi

       # Set new component name as terraform commands parameters
       tf_init "$env_path" "$env" "$component_tf_arg"
       tf_plan "$env_path" "$env" "$component_tf_arg"
       tf_validate "$env_path" "$env" "$policysource" "$component_tf_arg"
    ```

1. Do the same changes in single_action_runner function.

    ```text
    single_action_runner() {
    local env
    ...
    # Set maxdepth in find command
    find "$component_path" -mindepth 1 -maxdepth $maxdepth -type d | sort -r | while read -r env_path ; do
        env="$(basename "$env_path")"
        local component_tf_arg

        # Additional validation to get source folder hierarchy and find terraform configs
        if [[ "$env_path" =~ ^($base_dir)/($component)/(.+)/$env ]] ; then

            # Set a new component name to be used as terraform plan json file names
            component_tf_arg=$(echo ${BASH_REMATCH[3]} | sed -r 's/\//__/g')
        else
            component_tf_arg=$component
        fi
        ...
        case "$action" in
            apply )
            # Set new component name as terraform commands parameters
            tf_apply "$env_path" "$env" "$component_tf_arg"
            ;;

            init )
            # Set new component name as terraform commands parameters
            tf_init "$env_path" "$env" "$component_tf_arg"
            ;;

            plan )
            # Set new component name as terraform commands parameters
            tf_plan "$env_path" "$env" "$component_tf_arg"
            ;;

            show )
            # Set new component name as terraform commands parameters
            tf_show "$env_path" "$env" "$component_tf_arg"
            ;;

            validate )
            # Set new component name as terraform commands parameters
            tf_validate "$env_path" "$env" "$policysource" "$component_tf_arg"
            ;;
    ...
    ```

## Code Changes - Hierarchy creation - Environments as Root

```text
example-organization/
├── bootstrap
├── common
├── development
│   ├── finance
│   └── retail
├── non-production
│   ├── finance
│   └── retail
└── production
    ├── finance
    └── retail
```

![Environments as Root](change_resource_hierarchy-env_as_root.png)

*Figure 1 - An example of environments as root folders*

### Step 2-environments

1. Create the folder hierarchy for the business units in each environment.

    Example:

    2-environments/envs/development/main.tf

    ```hcl
    module "env" {
        source = "../../modules/env_baseline"

        env = "development"
        ...
    }

    /* Folder hierarchy creation */
    resource "google_folder" "finance" {
        display_name = "finance"
        parent       = module.env.env_folder
    }

    resource "google_folder" "retail" {
        display_name = "retail"
        parent       = module.env.env_folder
    }
    ```

1. Create an output with the flat representation of the new hierarchy in each environment. It will be used by next steps to host GCP projects.

    *Table 1 - Example output for Figure 1 resource hierarchy*

    | Folder Path | Folder Id |
    | --- | --- |
    | development | folders/0000000 |
    | development/finance | folders/11111111 |
    | development/retail | folders/2222222 |

    *Table 2 - Example output for resource hierarchy with more levels*

    | Folder Path | Folder Id |
    | --- | --- |
    | development | folders/0000000 |
    | development/us | folders/11111111 |
    | development/us/finance | folders/2222222 |
    | development/us/retail | folders/3333333 |
    | development/europe | folders/4444444 |
    | development/europe/finance | folders/5555555 |
    | development/europe/retail | folders/7777777 |

    Example:

    2-environments/envs/development/outputs.tf

    ```hcl
    ...
    /* Folder hierarchy output */
    output "folder_hierarchy" {
        value = {
        "development" = module.env.env_folder
        "development/finance" = google_folder.finance.name
        "development/retail" = google_folder.retail.name
        }
    }
    ```

### Step 4-projects

1. Change the base_env module to receive the new folder key (e.g. development/retail) in hierarchy map from step 2-environments.
1. This folder key should be used to get the folder where projects should be created.
    Example:

    4-projects/modules/base_env/variables.tf

    ```hcl
    ...
    variable "folder_hierarchy_key" {
        description = "Key of the folder hierarchy map to get the folder where projects should be created."
        type = string
        default = ""
    }
    ...
    ```

    4-projects/modules/base_env/main.tf

    ```hcl
    locals {
        ...
        env_folder_name = lookup(
        data.terraform_remote_state.environments_env.outputs.folder_hierarchy, var.folder_hierarchy_key
        , data.terraform_remote_state.environments_env.outputs.env_folder)
        ...
    }
    ...
    ```

1. Create your folder hierarchy above environment folders (development, non-production, production). Remember to keep the environment folders as leaf in source code folder hierarchy because this is the way tf-wrapper.sh - that is the bash script helper - works to apply terraform configurations.
1. For this example, just rename folder business_unit_1 and business_unit_2 to your Business Units names, i.e: finance and retail, to match example folder hierarchy.
1. Manually duplicate your source folder hierarchy to match your needs.
1. Change backend gcs prefix for each business unit shared resources.
    Example:

    4-projects/finance/shared/backend.tf

    ```hcl
    ...
    terraform {
        backend "gcs" {
            bucket = "<YOUR_PROJECTS_BACKEND_STATE_BUCKET>"
            prefix = "terraform/projects/finance/shared"
        }
    }
    ```

1. Review locals and business code in Cloud Build project pipelines.
    Example:

    4-projects/finance/shared/example_infra_pipeline.tf

    ```hcl
    locals {
        repo_names = ["finance-app"]
    }
    ...

    module "app_infra_cloudbuild_project" {
        source = "../../modules/single_project"
        ...
        primary_contact   = "example@example.com"
        secondary_contact = "example2@example.com"
        business_code     = "fin"
    }
    ```

1. Change backend gcs prefix for each business unit.
    Example:

    4-projects/finance/development/backend.tf

    ```hcl
    ...
    terraform {
        backend "gcs" {
            bucket = "<YOUR_PROJECTS_BACKEND_STATE_BUCKET>"
            prefix = "terraform/projects/finance/development"
        }
    }
    ```

1. Review business_code and business_unit to match your new business units names.
1. Set new folder_hierarchy_key parameter on base_env calls.

    Example:

    4-projects/finance/development/main.tf

    ```hcl
    module "env" {
        source = "../../modules/base_env"

        env                  = "development"
        business_code        = "fin"
        business_unit        = "finance"
        folder_hierarchy_key = "development/finance"
        ...
    }
    ```

## Code Changes - Hierarchy creation - Environments as Leafs

```text
example-organization/
├── bootstrap
├── common
├── finance
│   ├── development
│   ├── non-production
│   └── production
└── retail
    ├── development
    ├── non-production
    └── production
```

### Step 1-org

1. Create the folder hierarchy for the business units in the same level as bootstrap and common folders.
1. Create a new file with your folder hierarchy.

    Example:

    1-org/envs/shared/folder_hierarchy.tf

    ```hcl
    resource "google_folder" "finance" {
    display_name = "finance"
    parent       = local.parent
    }

    resource "google_folder" "retail" {
    display_name = "retail"
    parent       = local.parent
    }
    ```

1. Create an output with the flat presentation of the new hierarchy. It will be used in the next steps to host GCP projects.
1. In this scenario - environments as leaf - you should create the folder hierarchy before the environment folders creation that will happen in step 2. This is a big difference from scenario Environments as root where you create your business units folders hierarchy inside environment folders.

    *Table 3 - Example output for Figure 2 resource hierarchy*

    | Folder Path | Folder Id |
    | --- | --- |
    | finance | folders/11111111 |
    | retail | folders/2222222 |

    *Table 4 - Example output for resource hierarchy with more levels*
    | Folder Path | Folder Id |
    | --- | --- |
    | us | folders/0000000 |
    | us/finance | folders/11111111 |
    | us/retail | folders/2222222 |
    | europe | folders/3333333 |
    | europe/finance | folders/4444444 |
    | europe/retail | folders/5555555 |

    Example:

    1-org/envs/shared/outputs.tf

    ```hcl
    output "folder_hierarchy" {
        value = {
        "finance" = google_folder.finance.name
        "retail"  = google_folder.retail.name
        }
    }
    ```

### Step 2-environments

1. Create the environment folders for each business unit.
1. Under folder envs create your business unit folders.
1. Move environment folders (development, non-production, production) inside your business unit folders.
1. Duplicate environment folders inside business unit folders as many business units as needed.

    Example - Source folders structure considering Figure 2 example:

    ```text
    gcp-environment/
    ├── envs
    │   ├── finance
    │   │   ├── development
    │   │   ├── non-production
    │   │   └── production
    │   └── retail
    │       ├── development
    │       ├── non-production
    │       └── production
    └── modules
    ```

1. Change the base_env module to receive the new folder key (e.g. retail) in the hierarchy map from step 1-org.
1. This folder key should be used to get the parent folder where environment projects should be created.

    Example:

    2-environments/modules/base_env/variables.tf

    ```hcl
    ...
    variable "folder_hierarchy_key" {
        description = "Key of the folder hierarchy map to get the folder where projects should be created."
        type = string
        default = ""
    }
    ...
    ```

    2-environments/modules/base_env/main.tf

    ```hcl
    locals {
        ...
        parent = lookup(data.terraform_remote_state.org.outputs.folder_hierarchy, var.folder_hierarchy_key,
        data.terraform_remote_state.bootstrap.outputs.common_config.parent_id)
        ...
    }
    ```

1. You need to manually change backend gcs prefix for each business unit/environment resources.

    Example:

    2-environments/envs/retail/development/backend.tf

    ```hcl
    ...
    terraform {
        backend "gcs" {
            bucket = "<YOUR_BACKEND_STATE_BUCKET>"
            prefix = "terraform/environments/retail/development"
        }
    }
    ...
    ```

1. Set new folder_hierarchy_key parameter on base_env calls.

    Example:

    2-environments/envs/retail/development/main.tf

    ```hcl
    module "env" {
        source = "../../../modules/env_baseline"

        env                  = "development"
        environment_code     = "d"
        folder_hierarchy_key = "retail"
        ...
    }
    ```

### Step 3-networks

1. Keep shared folder in envs/shared path.
1. Under folder envs create your folder hierarchy. For this example, just create folders finance and retail, to match example folder hierarchy.
1. Move environment folders (development, non-production, production) inside your folder hierarchy. Remember to keep the environment folders as leafs in source code because this is the way tf-wrapper.sh - that is the bash script helper - works to apply terraform configurations.
1. Duplicate environment folders inside your folder hierarchy to match your needs.

    Example - Source folders structure considering Figure 2 example:

    ```text
    gcp-networks/
    ├── envs
    │   ├── finance
    │   │   ├── development
    │   │   ├── non-production
    │   │   └── production
    │   ├── retail
    │   │   ├── development
    │   │   ├── non-production
    │   │   └── production
    │   └── shared
    └── modules
    ```

1. Review shared resources to change environment folder names locals to business unit folder names as the parent folders now are business units instead of environments.

    Example:

    3-networks/envs/shared/main.tf

    ```hcl
    locals {
        ...
        common_folder_name = data.terraform_remote_state.org.outputs.common_folder_name

        # BUs folders instead of environment folders
        finance_folder_name = data.terraform_remote_state.org.outputs.folder_hierarchy["finance"]
        retail_folder_name  = data.terraform_remote_state.org.outputs.folder_hierarchy["retail"]
        ...
    }
    ```

1. Fix hierarchical firewall policies to apply in business unit parent folders instead of environment folders. Firewall policies should be  applied to folders under parent (organization or folder).

    Example:

    3-networks/envs/shared/hierarchical_firewall.tf

    ```hcl
    ...
    module "hierarchical_firewall_policy" {
        ...
        associations = [
            local.common_folder_name,
            local.bootstrap_folder_name,

            # BUs folders instead of environment folders
            local.finance_folder_name,
            local.retail_folder_name,
        ]
        rules = {
    ...
    ```

1. Change the base_env module to get terraform remote state folder path (e.g. retail/development).
1. This folder path should be used to get the terraform state folder that contains data needed to create network resources.

    Example:

    3-networks/modules/base_env/variables.tf

    ```hcl
    variable "env_state_folder" {
    description = "Path to remote state"
    type        = string
    default     = ""
    }
    ```

    Example:

    3-networks/modules/base_env/main.tf

    ```hcl
    ...
    data "terraform_remote_state" "environments_env" {
        backend = "gcs"

        config = {
        bucket = var.remote_state_bucket
            # Folder path to terraform remote state
            prefix = "terraform/environments/${var.env_state_folder}"
        }
    }
    ...
    ```

1. If you are using Hub and Spoke network mode, review the base and restricted aggregates subnets to match your environments requirements.
1. Make sure to update them in the base_env module.

    Example:

    3-networks/envs/shared/net-hubs-transitivity.tf

    ```hcl
    ...
    locals {
        enable_transitivity = var.enable_hub_and_spoke_transitivity
        base_regional_aggregates = {
            (local.default_region1) = [
                "10.0.0.0/16",
                "100.64.0.0/16"
            ]
            (local.default_region2) = [
                "10.1.0.0/16",
                "100.65.0.0/16"
            ]
        }
        restricted_regional_aggregates = {
            (local.default_region1) = [
                "10.8.0.0/16",
                "100.72.0.0/16"
            ]
            (local.default_region2) = [
                "10.9.0.0/16",
                "100.73.0.0/16"
            ]
        }
    }
    ...
    ```

    3-networks/modules/base_env/main.tf

    ```hcl
    ...
    locals {
        ...
        /*
        * Base network ranges
        */
        base_subnet_aggregates = ["10.0.0.0/16", "10.1.0.0/16", "100.64.0.0/16", "100.65.0.0/16"]
        ...
        /*
        * Restricted network ranges
        */
        restricted_subnet_aggregates = ["10.8.0.0/16", "10.9.0.0/16", "100.72.0.0/16", "100.73.0.0/16"]
        ...
    }
    ```

1. Change backend gcs prefix for each environment in each business unit.

    Example:

    3-networks/retail/development/backend.tf

    ```hcl
    ...
    terraform {
        backend "gcs" {
        bucket = "<YOUR_BACKEND_STATE_BUCKET>"
            # Folder path to terraform remote state bucket
            prefix = "terraform/networks/retail/development"
        }
    }
    ```

1. Review tfvars files symbolic links and modules source paths, as you added more folders in hierarchy it my change those paths.
1. Set new env_state_folder parameter on base_env calls.

    Example:

    3-networks/retail/development/main.tf

    ```hcl
    module "base_env" {
        source = "../../../modules/base_env"

        env              = local.env
        environment_code = local.environment_code
        env_state_folder = "retail/development"
        ...
    }
    ```

### Step 4-projects

1. Rename folder business_unit_1 to your Business Unit name, i.e: retail.
1. Rename folder business_unit_2 to your Business Unit name, i.e: finance.
1. Duplicate business_unit_X folder to create as many Business Units you need.
1. Change backend gcs prefix for each business unit shared resources.

    Example:

    4-projects/retail/shared/backend.tf

    ```hcl
    ...
    terraform {
        backend "gcs" {
            bucket = "<YOUR_PROJECTS_BACKEND_STATE_BUCKET>"
            prefix = "terraform/projects/retail/shared"
        }
    }
    ```

1. Review locals and business code in Cloud Build project pipelines.

    Example:

    4-projects/retail/shared/example_infra_pipeline.tf

    ```hcl
    locals {
        repo_names = ["retail-app"]
    }
    ...
    module "app_infra_cloudbuild_project" {
        source = "../../modules/single_project"
        ...
        business_code     = "ret"
        primary_contact   = "example@example.com"
        ...
    }
    ```

1. Change the base_env module to get terraform remote state folder path (e.g. retail/development).
1. This folder path should be used to get the terraform state folder that contains data needed to create network resources.

    Example:

    4-projects/modules/base_env/variables.tf

    ```hcl
    variable "env_state_folder" {
        description = "Path to remote state"
        type        = string
        default     = ""
    }
    ```

    4-projects/modules/base_env/main.tf

    ```hcl
    ...
    data "terraform_remote_state" "network_env" {
        backend = "gcs"

        config = {
            bucket = var.remote_state_bucket
            prefix = "terraform/networks/${var.env_state_folder}"
        }
    }

    data "terraform_remote_state" "environments_env" {
        backend = "gcs"

        config = {
            bucket = var.remote_state_bucket
            # Folder path to terraform remote state
            prefix = "terraform/environments/${var.env_state_folder}"
        }
    }
    ...
    ```

1. Change backend gcs prefix for each environment and business unit.

    Example:

    4-projects/finance/retail/backend.tf

    ```hcl
    ...
    terraform {
        backend "gcs" {
            bucket = "<YOUR_PROJECTS_BACKEND_STATE_BUCKET>"
            prefix = "terraform/projects/retail/development"
        }
    }
    ```

1. Review tfvars files symbolic links and modules source paths, as you added more folders in hierarchy it my change those paths.
1. Set new env_state_folder parameter on base_env calls.

    Example:

    4-projects/retail/development/main.tf

    ```hcl
    ...
    module "env" {
        source = "../../modules/base_env"

        env              = "development"
        business_code    = "ret"
        business_unit    = "retail"
        env_state_folder = "retail/development"
        ...
    }
    ```
