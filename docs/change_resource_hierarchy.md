# Guidance for modifications of resource hierarchy

Explains the instructions to change resource hierarchy during Terraform Foundation Example blueprint deployment.

The current deployment scenario of Terraform Foundation Example blueprint considers a flat resource hierarchy having one folder for each environment.

This document covers two additional scenarios:

- Environment folders as root of folders hierarchy
- Environment folders as leaf of folders hierarchy

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
└── <b>fldr-development</b><br>
&nbsp;&nbsp;&nbsp;&nbsp;├── finance<br>
&nbsp;&nbsp;&nbsp;&nbsp;└── retail<br>
└── <b>fldr-non-production</b><br>
&nbsp;&nbsp;&nbsp;&nbsp;├── finance<br>
&nbsp;&nbsp;&nbsp;&nbsp;└── retail<br>
└── <b>fldr-production</b><br>
&nbsp;&nbsp;&nbsp;&nbsp;├── finance<br>
&nbsp;&nbsp;&nbsp;&nbsp;└── retail<br>
</td>
<td style="font-family: monospace;">
example-organization/<br>
├── fldr-bootstrap<br>
├── fldr-common<br>
└── finance</b><br>
&nbsp;&nbsp;&nbsp;&nbsp;├── <b>fldr-development</b><br>
&nbsp;&nbsp;&nbsp;&nbsp;├── <b>fldr-non-production</b><br>
&nbsp;&nbsp;&nbsp;&nbsp;└── <b>fldr-production</b><br>
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

Review tf-wrapper.sh.

1. Create a new variable maxdepth to set how many source folder levels should be searched for terraform configurations.

    ```bash
    ...
    tmp_plan="${base_dir}/tmp_plan" #if you change this, update build triggers
    environments_regex="^(development|non-production|production|shared)$"

    # Create maxdepth variable
    maxdepth=2  #<- Must be configured base in your directory design

    ## Terraform apply for single environment.
    tf_apply() {
    ...
    ```

1. Change find commands to use maxdepth variable on all terraform commands. Make sure you do the same changes in functions: tf_plan_validate_all and single_action_runner.

    ```bash
    tf_plan_validate_all() {
    local env
    ...
    # Set maxdepth in find command
    find "$component_path" -mindepth 1 -maxdepth $maxdepth -type d | while read -r env_path ; do
        env="$(basename "$env_path")"
    ```

1. Add validation to check your new folder hierarchy and find terraform config files.

    ```bash
     if [[ "$env" =~ $environments_regex ]] ; then
       local component_tf_arg
       # Additional validation to get source folder hierarchy and find terraform configs
       if [[ "$env_path" =~ ^($base_dir)/($component)/(.+)/$env ]] ; then
    ```

1. Set a new component name to be used as terraform plan json filenames and set it as terraform commands parameters.

    ```bash
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

    ```bash
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
└── development
    ├── finance
    └── retail
└── non-production
    ├── finance
    └── retail
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
