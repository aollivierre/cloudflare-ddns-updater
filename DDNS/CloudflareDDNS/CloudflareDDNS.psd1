@{
    # Script module or binary module file associated with this manifest.
    RootModule = 'CloudflareDDNS.psm1'
    
    # Version number of this module.
    ModuleVersion = '1.0.0'
    
    # Supported PSEditions
    # CompatiblePSEditions = @()
    
    # ID used to uniquely identify this module
    GUID = '1db4c6e3-7e0c-4ad1-8c8c-564081a37241'
    
    # Author of this module
    Author = 'Your Name'
    
    # Company or vendor of this module
    CompanyName = 'Your Company'
    
    # Copyright statement for this module
    Copyright = '(c) 2023. All rights reserved.'
    
    # Description of the functionality provided by this module
    Description = 'Updates Cloudflare DNS records with your current public IP address.'
    
    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '5.1'
    
    # Modules that must be imported into the global environment prior to importing this module
    # RequiredModules = @()
    
    # Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
    FunctionsToExport = @(
        'Update-CloudflareDNSRecord',
        'Initialize-CloudflareDDNSConfig',
        'Show-CloudflareDDNSMenu',
        'Show-CloudflareDDNSStatus',
        'Install-CloudflareDDNSTask',
        'Remove-CloudflareDDNSTask',
        'Test-CloudflareAPIConnection',
        'Show-CloudflareDDNSLog',
        'Clear-CloudflareDDNSLog',
        'Configure-CloudflareAPIToken',
        'Edit-CloudflareConfig',
        'Run-CloudflareDDNSTask',
        'Toggle-CloudflareDDNSTask',
        'Restart-TaskSchedulerService'
    )
    
    # Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
    CmdletsToExport = @()
    
    # Variables to export from this module
    VariablesToExport = '*'
    
    # Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
    AliasesToExport = @()
    
    # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
    PrivateData = @{
        PSData = @{
            # Tags applied to this module. These help with module discovery in online galleries.
            Tags = @('Cloudflare', 'DNS', 'DDNS', 'IP')
            
            # A URL to the license for this module.
            # LicenseUri = ''
            
            # A URL to the main website for this project.
            # ProjectUri = ''
            
            # A URL to an icon representing this module.
            # IconUri = ''
            
            # ReleaseNotes of this module
            ReleaseNotes = 'Initial release of CloudflareDDNS module'
        }
    }
} 