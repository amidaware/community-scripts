<#
.SYNOPSIS
    Outputs Tactical RMM pre-made variables with prefixes for exemple.

    Documentation for script variables: https://docs.tacticalrmm.com/script_variables/  

    Documentation for custom fields: https://docs.tacticalrmm.com/functions/custom_fields/

    Documentation for global keystore/custom fields: https://docs.tacticalrmm.com/functions/keystore/

.EXEMPLE
    Example input in Environment vars:
        version={{agent.version}}
        operating_system={{agent.operating_system}}
        plat={{agent.plat}}
        hostname={{agent.hostname}}
        local_ips={{agent.local_ips}}
        public_ip={{agent.public_ip}}
        agent_id={{agent.agent_id}}
        last_seen={{agent.last_seen}}
        total_ram={{agent.total_ram}}
        boot_time={{agent.boot_time}}
        logged_in_username={{agent.logged_in_username}}
        last_logged_in_user={{agent.last_logged_in_user}}
        monitoring_type={{agent.monitoring_type}}
        description={{agent.description}}
        mesh_node_id={{agent.mesh_node_id}}
        overdue_email_alert={{agent.overdue_email_alert}}
        overdue_text_alert={{agent.overdue_text_alert}}
        overdue_dashboard_alert={{agent.overdue_dashboard_alert}}
        offline_time={{agent.offline_time}}
        overdue_time={{agent.overdue_time}}
        check_interval={{agent.check_interval}}
        needs_reboot={{agent.needs_reboot}}
        choco_installed={{agent.choco_installed}}
        patches_last_installed={{agent.patches_last_installed}}
        timezone={{agent.timezone}}
        maintenance_mode={{agent.maintenance_mode}}
        block_policy_inheritance={{agent.block_policy_inheritance}}
        alert_template={{agent.alert_template}}
        site={{agent.site}}

        client_name={{client.name}}

        site_name={{site.name}}
        site_client={{site.client}}

    Custom:
        agent.custom={{agent.custom}}
        site.custom={{site.custom}}
        client.custom={{client.custom}}
        global.custom={{global.custom}}

.NOTE
    Author: SAN
    Date: 06.01.25
    #public

#>

# Block 1: Agent pre-made variables
Write-Output "===== Agent Information ====="
Write-Output "agent.version: $env:version"
Write-Output "agent.operating_system: $env:operating_system"
Write-Output "agent.plat: $env:plat"
Write-Output "agent.hostname: $env:hostname"
Write-Output "agent.local_ips: $env:local_ips"
Write-Output "agent.public_ip: $env:public_ip"
Write-Output "agent.agent_id: $env:agent_id"
Write-Output "agent.last_seen: $env:last_seen"
Write-Output "agent.total_ram: $env:total_ram"
Write-Output "agent.boot_time: $env:boot_time"
Write-Output "agent.logged_in_username: $env:logged_in_username"
Write-Output "agent.last_logged_in_user: $env:last_logged_in_user"
Write-Output "agent.monitoring_type: $env:monitoring_type"
Write-Output "agent.description: $env:description"
Write-Output "agent.mesh_node_id: $env:mesh_node_id"
Write-Output "agent.overdue_email_alert: $env:overdue_email_alert"
Write-Output "agent.overdue_text_alert: $env:overdue_text_alert"
Write-Output "agent.overdue_dashboard_alert: $env:overdue_dashboard_alert"
Write-Output "agent.offline_time: $env:offline_time"
Write-Output "agent.overdue_time: $env:overdue_time"
Write-Output "agent.check_interval: $env:check_interval"
Write-Output "agent.needs_reboot: $env:needs_reboot"
Write-Output "agent.choco_installed: $env:choco_installed"
Write-Output "agent.patches_last_installed: $env:patches_last_installed"
Write-Output "agent.timezone: $env:timezone"
Write-Output "agent.maintenance_mode: $env:maintenance_mode"
Write-Output "agent.block_policy_inheritance: $env:block_policy_inheritance"
Write-Output "agent.alert_template: $env:alert_template"
Write-Output "agent.site: $env:site"
Write-Output ""

# Block 2: Client pre-made variables
Write-Output "===== Client Information ====="
Write-Output "client.name: $env:client_name"
Write-Output ""

# Block 3: Site pre-made variables
Write-Output "===== Site Information ====="
Write-Output "site.name: $env:site_name"
Write-Output "site.client: $env:site_client"
Write-Output ""

# Block 4: Agent Custom fields
Write-Output "===== Agent Custom fields ====="
Write-Output ""

# Block 5: Site Custom fields
Write-Output "===== Site Custom fields ====="
Write-Output ""

# Block 6: Client Custom fields
Write-Output "===== Client Custom fields ====="
Write-Output ""

# Block 7: Global Custom fields
Write-Output "===== Global Custom fields ====="
Write-Output ""