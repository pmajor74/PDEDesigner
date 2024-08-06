@{
    RootModule = 'PDEDesigner.psm1'
    ModuleVersion = '0.7'
    GUID = 'ec08c641-03a9-4fd0-80ce-9620f865de14'
    Author = 'Patrick Major'
    Description = 'PowerShell Design Environment GUI Editor'
    PowerShellVersion = '5.1'
    RequiredAssemblies = @('PresentationFramework', 'PresentationCore', 'WindowsBase')
    FunctionsToExport = @('Start-PDEDesigner')
    PrivateData = @{
        PSData = @{
            Tags = @('GUI', 'Designer', 'WPF')
            ProjectUri = 'https://github.com/pmajor74/PDEDesigner'
        }
    }
}