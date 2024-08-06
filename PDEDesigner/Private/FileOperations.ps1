function Save-Layout {
    $saveFileDialog = New-Object Microsoft.Win32.SaveFileDialog
    $saveFileDialog.Filter = "PowerShell scripts (*.ps1)|*.ps1"
    $saveFileDialog.InitialDirectory = $PSScriptRoot
    $saveFileDialog.FileName = "GeneratedGUI.ps1"
    if ($saveFileDialog.ShowDialog()) {
        $customCode = $global:loadedCustomCode

        if (-not $customCode -and (Test-Path $saveFileDialog.FileName)) {
            $existingContent = Get-Content $saveFileDialog.FileName -Raw
            if ($existingContent -match '(?s)# END-PDEDESIGNER-CONTROLS\s*(.*?)\s*# BEGIN-PDEDESIGNER-SHOW-WINDOW') {
                $customCode = $matches[1].Trim()
            }
        }

        $script = @'
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

# BEGIN-PDEDESIGNER-XAML
[xml]$xaml = @"
<Window 
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="Generated GUI" Height="{0}" Width="{1}">
    <Grid>
        <Canvas>
'@

        $script = $script -f $designCanvas.ActualHeight, $designCanvas.ActualWidth

        foreach ($control in $designCanvas.Children) {
            if ($control.Tag -ne "SelectionBorder") {
                $left = [System.Windows.Controls.Canvas]::GetLeft($control)
                $top = [System.Windows.Controls.Canvas]::GetTop($control)
                
                $xamlControl = ""
                switch ($control.GetType().Name) {
                    "Button" { 
                        $xamlControl = '<Button Content="{0}" Width="{1}" Height="{2}" Canvas.Left="{3}" Canvas.Top="{4}" Name="{5}" />' -f $control.Content, $control.Width, $control.Height, $left, $top, $control.Name
                    }
                    "TextBox" { 
                        $xamlControl = '<TextBox Text="{0}" Width="{1}" Height="{2}" Canvas.Left="{3}" Canvas.Top="{4}" Name="{5}" />' -f $control.Text, $control.Width, $control.Height, $left, $top, $control.Name
                    }
                    "Label" { 
                        $xamlControl = '<Label Content="{0}" Width="{1}" Height="{2}" Canvas.Left="{3}" Canvas.Top="{4}" Name="{5}" />' -f $control.Content, $control.Width, $control.Height, $left, $top, $control.Name
                    }
                    "ComboBox" { 
                        $xamlControl = '<ComboBox Width="{0}" Height="{1}" Canvas.Left="{2}" Canvas.Top="{3}" Name="{4}">' -f $control.Width, $control.Height, $left, $top, $control.Name
                        foreach ($item in $control.Items) {
                            $xamlControl += "<ComboBoxItem Content=`"$item`" />"
                        }
                        $xamlControl += "</ComboBox>"
                    }
                    
                    # todo: add more controls later
                    # todo: also make it so the controls are externalized as configuration files so that they can be loaded at runtime and extensions can be made as needed
                }
                $script += "            $xamlControl`n"
            }
        }

        $script += @'
        </Canvas>
    </Grid>
</Window>
"@
# END-PDEDESIGNER-XAML

$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

# BEGIN-PDEDESIGNER-CONTROLS

'@

        foreach ($control in $designCanvas.Children) {
            if ($control.Tag -ne "SelectionBorder" -and $control.Name) {
                $script += "`$$($control.Name) = `$window.FindName('$($control.Name)')`n"
                
                # Add event handlers
                if ($control.Tag -is [Hashtable]) {
                    foreach ($eventName in $control.Tag.Keys) {
                        $eventHandler = $control.Tag[$eventName]
                        $script += @"
`$$($control.Name).Add_$eventName({
$eventHandler
})

"@
                    }
                }
            }
        }

        $script += "# END-PDEDESIGNER-CONTROLS`n`n"

        if ($customCode) {
            $script += $customCode + "`n`n"
        }

        $script += @'
# BEGIN-PDEDESIGNER-SHOW-WINDOW
# Show the window
$window.ShowDialog() | Out-Null
# END-PDEDESIGNER-SHOW-WINDOW
'@

        $script | Out-File -FilePath $saveFileDialog.FileName -Encoding utf8
        Write-Host "Layout saved as PowerShell script: $($saveFileDialog.FileName)"
    }
}

function Load-Layout {
    $openFileDialog = New-Object Microsoft.Win32.OpenFileDialog
    $openFileDialog.Filter = "PowerShell scripts (*.ps1)|*.ps1"
    $openFileDialog.InitialDirectory = $PSScriptRoot
    if ($openFileDialog.ShowDialog()) {
        $content = Get-Content $openFileDialog.FileName -Raw

        # Extract custom code
        if ($content -match '(?s)# END-PDEDESIGNER-CONTROLS\s*(.*?)\s*# BEGIN-PDEDESIGNER-SHOW-WINDOW') {
            $global:loadedCustomCode = $matches[1].Trim()
        } else {
            $global:loadedCustomCode = $null
        }

        # Extract XAML
        if ($content -match '(?s)# BEGIN-PDEDESIGNER-XAML(.*?)# END-PDEDESIGNER-XAML') {
            $xamlContent = $matches[1].Trim()
            
            # Extract the XAML string
            if ($xamlContent -match '(?s)\[xml\]\$xaml\s*=\s*@"(.*?)"@') {
                $xamlString = $matches[1].Trim()
                
                # Load XAML
                $xaml = [xml]$xamlString
                $designCanvas.Children.Clear()

                # Create controls based on XAML
                foreach ($controlXaml in $xaml.Window.Grid.Canvas.ChildNodes) {
                    $controlType = $controlXaml.LocalName
                    $control = New-Object "System.Windows.Controls.$controlType"

                    # Set common properties
                    $control.Name = $controlXaml.Name
                    $control.Width = [double]::Parse($controlXaml.Width)
                    $control.Height = [double]::Parse($controlXaml.Height)
                    [System.Windows.Controls.Canvas]::SetLeft($control, [double]::Parse($controlXaml.GetAttribute("Canvas.Left")))
                    [System.Windows.Controls.Canvas]::SetTop($control, [double]::Parse($controlXaml.GetAttribute("Canvas.Top")))

                    # Set control-specific properties
                    switch ($controlType) {
                        "Button" { $control.Content = $controlXaml.Content }
                        "TextBox" { $control.Text = $controlXaml.Text }
                        "Label" { $control.Content = $controlXaml.Content }
                        "ComboBox" { 
                            foreach ($item in $controlXaml.ComboBoxItem) {
                                $control.Items.Add($item.Content) | Out-Null
                            }
                            $control.SelectedIndex = 0
                        }
                        
                    }

                    # Extract and set event handlers
                    $eventHandlers = [regex]::Matches($content, "(?s)`$$($control.Name)\.Add_(\w+)\(\{(.*?)\}\)")
                    foreach ($match in $eventHandlers) {
                        $eventName = $match.Groups[1].Value
                        $eventHandler = $match.Groups[2].Value.Trim()
                        if (-not $control.Tag) { $control.Tag = @{} }
                        $control.Tag[$eventName] = $eventHandler

                        # Compile and attach the event handler
                        $scriptBlock = [ScriptBlock]::Create($eventHandler)
                        $control."Add_$eventName"($scriptBlock)
                    }

                    Make-DraggableAndSelectable $control
                    $designCanvas.Children.Add($control)
                }

                # Select the first control to update the Properties and Events tabs
                if ($designCanvas.Children.Count -gt 0) {
                    Select-Control $designCanvas.Children[0]
                }

                Write-Host "Layout loaded successfully from: $($openFileDialog.FileName)"
            }
            else {
                Write-Host "Failed to extract XAML string from the file."
            }
        }
        else {
            Write-Host "Failed to find PDEDESIGNER-XAML section in the file."
        }
    }
}

function Show-Preview {
    $previewXaml = @"
<Window 
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="Preview" Height="$($designCanvas.ActualHeight)" Width="$($designCanvas.ActualWidth)">
    <Grid>
        <Canvas x:Name="PreviewCanvas">
        </Canvas>
    </Grid>
</Window>
"@

    $reader = New-Object System.Xml.XmlNodeReader ([xml]$previewXaml)
    $previewWindow = [Windows.Markup.XamlReader]::Load($reader)
    $previewCanvas = $previewWindow.FindName("PreviewCanvas")

    foreach ($control in $designCanvas.Children) {
        if ($control.Tag -ne "SelectionBorder") {
            $clone = New-Object $control.GetType()
            $clone.Width = $control.Width
            $clone.Height = $control.Height
            [System.Windows.Controls.Canvas]::SetLeft($clone, [System.Windows.Controls.Canvas]::GetLeft($control))
            [System.Windows.Controls.Canvas]::SetTop($clone, [System.Windows.Controls.Canvas]::GetTop($control))

            switch ($control.GetType().Name) {
                "Button" { $clone.Content = $control.Content }
                "TextBox" { $clone.Text = $control.Text }
                "Label" { $clone.Content = $control.Content }
                "ComboBox" { 
                    foreach ($item in $control.Items) {
                        $clone.Items.Add($item)
                    }
                    $clone.SelectedIndex = $control.SelectedIndex
                }
                
            }

            # Add event handlers
            if ($control.Tag -is [Hashtable]) {
                foreach ($eventName in $control.Tag.Keys) {
                    $eventHandler = $control.Tag[$eventName]
                    $scriptBlock = [ScriptBlock]::Create($eventHandler)
                    $clone."Add_$eventName"($scriptBlock)
                }
            }

            $previewCanvas.Children.Add($clone)
        }
    }

    $previewWindow.ShowDialog()
}

function Initialize-FileOperations {
    $script:saveButton.Add_Click({ Save-Layout })
    $script:loadButton.Add_Click({ Load-Layout })
    $script:previewButton.Add_Click({ Show-Preview })
}