function Start-PDEDesigner {
    [CmdletBinding()]
    param()

    Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

    # Load XAML
    [xml]$xaml = Get-Content "$PSScriptRoot\..\Private\MainWindow.xaml"
    $reader = New-Object System.Xml.XmlNodeReader $xaml
    $script:window = [Windows.Markup.XamlReader]::Load($reader)

    # Get controls
    $script:toolboxListBox = $window.FindName("ToolboxListBox")
    $script:designCanvas = $window.FindName("DesignCanvas")
    $script:propertiesGrid = $window.FindName("PropertiesGrid")
    $script:eventsGrid = $window.FindName("EventsGrid")
    $script:saveButton = $window.FindName("SaveButton")
    $script:loadButton = $window.FindName("LoadButton")
    $script:previewButton = $window.FindName("PreviewButton")

    # Initialize controls and file operations
    Initialize-Controls
    Initialize-FileOperations

    # Show the window
    $window.ShowDialog() | Out-Null
}