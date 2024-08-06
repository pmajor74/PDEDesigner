# Global variables
$script:selectedControl = $null
$script:isDragging = $false
$script:lastMousePos = $null
$script:selectionBorder = $null
$script:loadedCustomCode = $null
$script:eventsGrid = $null
$script:snapToGrid = $false
$script:isResizing = $false

function Initialize-Controls {

    $script:propertiesGrid = $window.FindName("PropertiesGrid")
    $script:eventsGrid = $window.FindName("EventsGrid")
    $script:eventsGrid.AddHandler(
        [System.Windows.Controls.Button]::ClickEvent,
        [System.Windows.RoutedEventHandler]{
            param($sender, $e)
            if ($e.OriginalSource -is [System.Windows.Controls.Button]) {
                $eventName = $e.OriginalSource.Tag
                Edit-EventHandler $eventName
            }
        }
    )

    # Populate toolbox
    $toolboxItems = @(
        "Button",
        "TextBox",
        "Label",
        "ComboBox",
        "CheckBox",
        "RadioButton",
        "ListBox",
        "Slider",
        "ProgressBar",
        "DatePicker",
        "PasswordBox",
        "RichTextBox"
    )

    $script:toolboxListBox.ItemsSource = $toolboxItems

    # Add event handlers
    $script:designCanvas.Add_MouseLeftButtonDown({
        if ($_.OriginalSource -eq $script:designCanvas) {
            $script:selectedControl = $null
            Update-SelectionBorder $null
            $script:propertiesGrid.ItemsSource = $null
        }
    })

    $script:designCanvas.Add_MouseMove({
        if ($script:isDragging -and $script:selectedControl -ne $null) {
            $currentPos = [System.Windows.Input.Mouse]::GetPosition($script:designCanvas)
            $offset = New-Object System.Windows.Vector(
                ($currentPos.X - $script:lastMousePos.X),
                ($currentPos.Y - $script:lastMousePos.Y)
            )
            $newLeft = [System.Windows.Controls.Canvas]::GetLeft($script:selectedControl) + $offset.X
            $newTop = [System.Windows.Controls.Canvas]::GetTop($script:selectedControl) + $offset.Y
            
            [System.Windows.Controls.Canvas]::SetLeft($script:selectedControl, $newLeft)
            [System.Windows.Controls.Canvas]::SetTop($script:selectedControl, $newTop)
            $script:lastMousePos = $currentPos

            Update-ControlProperties "Left" $newLeft
            Update-ControlProperties "Top" $newTop

            Update-SelectionBorder $script:selectedControl
        }
    })

    $script:designCanvas.Add_MouseLeftButtonUp({
        if ($script:isDragging) {
            $script:isDragging = $false
            if ($script:selectedControl -ne $null) {
                $script:selectedControl.ReleaseMouseCapture()
            }
        }
    })

    # Toolbox item drag start
    $script:toolboxListBox.Add_PreviewMouseLeftButtonDown({
        $item = $_.OriginalSource.DataContext
        if ($item -is [string]) {
            $dragData = New-Object Windows.DataObject([Windows.DataFormats]::StringFormat, $item)
            [Windows.DragDrop]::DoDragDrop($script:toolboxListBox, $dragData, [Windows.DragDropEffects]::Copy)
        }
    })

    # Canvas drop event
    $script:designCanvas.Add_Drop({
        $controlType = $_.Data.GetData([Windows.DataFormats]::StringFormat)
        $dropPosition = $_.GetPosition($script:designCanvas)

        $control = New-Object System.Windows.Controls.$controlType

        # Set properties based on control type
        switch ($controlType) {
            "Button" { 
                $control.Content = "Button"
                $control.Name = "Button" + ($script:designCanvas.Children.Count + 1)
            }
            "TextBox" { 
                $control.Text = "TextBox"
                $control.Name = "TextBox" + ($script:designCanvas.Children.Count + 1)
            }
            "Label" { 
                $control.Content = "Label"
                $control.Name = "Label" + ($script:designCanvas.Children.Count + 1)
            }
            "ComboBox" { 
                $control.Items.Add("Item 1") | Out-Null
                $control.Items.Add("Item 2") | Out-Null
                $control.Items.Add("Item 3") | Out-Null
                $control.SelectedIndex = 0
                $control.Name = "ComboBox" + ($script:designCanvas.Children.Count + 1)
            }
            "CheckBox" {
                $control.Content = "CheckBox"
                $control.Name = "CheckBox" + ($script:designCanvas.Children.Count + 1)
            }
            "RadioButton" {
                $control.Content = "RadioButton"
                $control.Name = "RadioButton" + ($script:designCanvas.Children.Count + 1)
            }
            "ListBox" {
                $control.Items.Add("Item 1") | Out-Null
                $control.Items.Add("Item 2") | Out-Null
                $control.Items.Add("Item 3") | Out-Null
                $control.Name = "ListBox" + ($script:designCanvas.Children.Count + 1)
            }
            "Slider" {
                $control.Minimum = 0
                $control.Maximum = 100
                $control.Value = 50
                $control.Name = "Slider" + ($script:designCanvas.Children.Count + 1)
            }
            "ProgressBar" {
                $control.Minimum = 0
                $control.Maximum = 100
                $control.Value = 50
                $control.Name = "ProgressBar" + ($script:designCanvas.Children.Count + 1)
            }
            "DatePicker" {
                $control.Name = "DatePicker" + ($script:designCanvas.Children.Count + 1)
            }
            "PasswordBox" {
                $control.Password = "password"
                $control.Name = "PasswordBox" + ($script:designCanvas.Children.Count + 1)
            }
            "RichTextBox" {
                $control.Name = "RichTextBox" + ($script:designCanvas.Children.Count + 1)
            }
        }

        $control.Width = 100
        $control.Height = 30

        # Add the control to the canvas at the drop position
        $script:designCanvas.Children.Add($control)
        [System.Windows.Controls.Canvas]::SetLeft($control, $dropPosition.X)
        [System.Windows.Controls.Canvas]::SetTop($control, $dropPosition.Y)

        # Make the control draggable and selectable
        Make-DraggableAndSelectable $control

        Select-Control $control
    })

    # Add event handler for child controls
    $script:designCanvas.Add_PreviewMouseLeftButtonDown({
        if ($_.OriginalSource -eq $script:designCanvas) {
            End-ResizeMode
            $script:selectedControl = $null
            Update-SelectionBorder $null
            $script:propertiesGrid.ItemsSource = $null
            $script:eventsGrid.ItemsSource = $null
        }
    })

    $script:propertiesGrid.Add_CellEditEnding({
        param($sender, $e)
        if ($e.Column.DisplayIndex -eq 1) {  # Value column
            $propertyName = $e.Row.Item.Name
            $propertyValue = $e.EditingElement.Text
            
            # Apply the change immediately
            Update-ControlProperties $propertyName $propertyValue

            # Use BeginInvoke to schedule a UI update after the current operation is complete
            $script:propertiesGrid.Dispatcher.BeginInvoke([Action]{
                $script:designCanvas.InvalidateVisual()
            }, [System.Windows.Threading.DispatcherPriority]::Background)
        }
    })

    $script:propertiesGrid.Add_SourceUpdated({
        $script:propertiesGrid.Items.Refresh()
    })    
}

function End-ResizeMode {
    $global:isResizing = $false
    $global:resizeMode = "None"
    $script:designCanvas.ReleaseMouseCapture()
}

function Update-SelectionBorder {
    param($control)

    if ($global:selectionBorder -ne $null) {
        $script:designCanvas.Children.Remove($global:selectionBorder)
        $global:selectionBorder = $null
    }

    if ($control -ne $null) {
        $border = New-Object System.Windows.Controls.Canvas
        $border.Tag = "SelectionBorder"

        $rectangle = New-Object System.Windows.Shapes.Rectangle
        $rectangle.Stroke = [System.Windows.Media.Brushes]::Blue
        $rectangle.StrokeThickness = 1
        $rectangle.Fill = [System.Windows.Media.Brushes]::Transparent

        $border.Children.Add($rectangle)

        $resizeHandles = @("TopLeft", "Top", "TopRight", "Left", "Right", "BottomLeft", "Bottom", "BottomRight")
        foreach ($handle in $resizeHandles) {
            $ellipse = New-Object System.Windows.Shapes.Ellipse
            $ellipse.Width = 10
            $ellipse.Height = 10
            $ellipse.Fill = [System.Windows.Media.Brushes]::White
            $ellipse.Stroke = [System.Windows.Media.Brushes]::Blue
            $ellipse.StrokeThickness = 1
            $ellipse.Tag = $handle

            $border.Children.Add($ellipse)
        }

        $left = [System.Windows.Controls.Canvas]::GetLeft($control)
        $top = [System.Windows.Controls.Canvas]::GetTop($control)
        
        [System.Windows.Controls.Canvas]::SetLeft($border, $left)
        [System.Windows.Controls.Canvas]::SetTop($border, $top)
        $border.Width = $control.ActualWidth
        $border.Height = $control.ActualHeight

        $script:designCanvas.Children.Add($border)
        $global:selectionBorder = $border

        Update-ResizeHandles $border
        Add-ResizeHandlers $border $control
    }
}

function Update-ResizeHandles {
    param($border)

    $width = $border.Width
    $height = $border.Height

    $handles = $border.Children | Where-Object { $_ -is [System.Windows.Shapes.Ellipse] }
    foreach ($handle in $handles) {
        switch ($handle.Tag) {
            "TopLeft" { [System.Windows.Controls.Canvas]::SetLeft($handle, -5); [System.Windows.Controls.Canvas]::SetTop($handle, -5) }
            "Top" { [System.Windows.Controls.Canvas]::SetLeft($handle, $width / 2 - 5); [System.Windows.Controls.Canvas]::SetTop($handle, -5) }
            "TopRight" { [System.Windows.Controls.Canvas]::SetLeft($handle, $width - 5); [System.Windows.Controls.Canvas]::SetTop($handle, -5) }
            "Left" { [System.Windows.Controls.Canvas]::SetLeft($handle, -5); [System.Windows.Controls.Canvas]::SetTop($handle, $height / 2 - 5) }
            "Right" { [System.Windows.Controls.Canvas]::SetLeft($handle, $width - 5); [System.Windows.Controls.Canvas]::SetTop($handle, $height / 2 - 5) }
            "BottomLeft" { [System.Windows.Controls.Canvas]::SetLeft($handle, -5); [System.Windows.Controls.Canvas]::SetTop($handle, $height - 5) }
            "Bottom" { [System.Windows.Controls.Canvas]::SetLeft($handle, $width / 2 - 5); [System.Windows.Controls.Canvas]::SetTop($handle, $height - 5) }
            "BottomRight" { [System.Windows.Controls.Canvas]::SetLeft($handle, $width - 5); [System.Windows.Controls.Canvas]::SetTop($handle, $height - 5) }
        }
    }
}

function Get-ControlProperties($control) {
    $properties = New-Object System.Collections.ObjectModel.ObservableCollection[ObservableProperty]
    
    # Common properties for all controls
    $properties.Add([ObservableProperty]@{Name="Name"; Value=$control.Name})
    $properties.Add([ObservableProperty]@{Name="Width"; Value=$control.Width})
    $properties.Add([ObservableProperty]@{Name="Height"; Value=$control.Height})
    $properties.Add([ObservableProperty]@{Name="Left"; Value=[System.Windows.Controls.Canvas]::GetLeft($control)})
    $properties.Add([ObservableProperty]@{Name="Top"; Value=[System.Windows.Controls.Canvas]::GetTop($control)})
    $properties.Add([ObservableProperty]@{Name="Visibility"; Value=$control.Visibility})
    $properties.Add([ObservableProperty]@{Name="IsEnabled"; Value=$control.IsEnabled})
    $properties.Add([ObservableProperty]@{Name="Opacity"; Value=$control.Opacity})
    $properties.Add([ObservableProperty]@{Name="ToolTip"; Value=$control.ToolTip})

    # Control-specific properties
    switch ($control.GetType().Name) {
        "Button" { 
            $properties.Add([ObservableProperty]@{Name="Content"; Value=$control.Content})
            $properties.Add([ObservableProperty]@{Name="FontSize"; Value=$control.FontSize})
            $properties.Add([ObservableProperty]@{Name="FontWeight"; Value=$control.FontWeight})
            $properties.Add([ObservableProperty]@{Name="Background"; Value=$control.Background})
            $properties.Add([ObservableProperty]@{Name="Foreground"; Value=$control.Foreground})
            $properties.Add([ObservableProperty]@{Name="Click"; Value="Add_Click"})
        }
        "TextBox" { 
            $properties.Add([ObservableProperty]@{Name="Text"; Value=$control.Text})
            $properties.Add([ObservableProperty]@{Name="FontSize"; Value=$control.FontSize})
            $properties.Add([ObservableProperty]@{Name="FontWeight"; Value=$control.FontWeight})
            $properties.Add([ObservableProperty]@{Name="TextWrapping"; Value=$control.TextWrapping})
            $properties.Add([ObservableProperty]@{Name="AcceptsReturn"; Value=$control.AcceptsReturn})
            $properties.Add([ObservableProperty]@{Name="TextChanged"; Value="Add_TextChanged"})
        }
        "Label" { 
            $properties.Add([ObservableProperty]@{Name="Content"; Value=$control.Content})
            $properties.Add([ObservableProperty]@{Name="FontSize"; Value=$control.FontSize})
            $properties.Add([ObservableProperty]@{Name="FontWeight"; Value=$control.FontWeight})
            $properties.Add([ObservableProperty]@{Name="Background"; Value=$control.Background})
            $properties.Add([ObservableProperty]@{Name="Foreground"; Value=$control.Foreground})
        }
        "ComboBox" { 
            $properties.Add([ObservableProperty]@{Name="SelectedIndex"; Value=$control.SelectedIndex})
            $properties.Add([ObservableProperty]@{Name="Items"; Value=($control.Items -join ", ")})
            $properties.Add([ObservableProperty]@{Name="IsEditable"; Value=$control.IsEditable})
            $properties.Add([ObservableProperty]@{Name="SelectionChanged"; Value="Add_SelectionChanged"})
        }
        "CheckBox" {
            $properties.Add([ObservableProperty]@{Name="Content"; Value=$control.Content})
            $properties.Add([ObservableProperty]@{Name="IsChecked"; Value=$control.IsChecked})
            $properties.Add([ObservableProperty]@{Name="Checked"; Value="Add_Checked"})
            $properties.Add([ObservableProperty]@{Name="Unchecked"; Value="Add_Unchecked"})
        }
        "RadioButton" {
            $properties.Add([ObservableProperty]@{Name="Content"; Value=$control.Content})
            $properties.Add([ObservableProperty]@{Name="IsChecked"; Value=$control.IsChecked})
            $properties.Add([ObservableProperty]@{Name="GroupName"; Value=$control.GroupName})
            $properties.Add([ObservableProperty]@{Name="Checked"; Value="Add_Checked"})
        }
        "ListBox" {
            $properties.Add([ObservableProperty]@{Name="SelectedIndex"; Value=$control.SelectedIndex})
            $properties.Add([ObservableProperty]@{Name="Items"; Value=($control.Items -join ", ")})
            $properties.Add([ObservableProperty]@{Name="SelectionMode"; Value=$control.SelectionMode})
            $properties.Add([ObservableProperty]@{Name="SelectionChanged"; Value="Add_SelectionChanged"})
        }
        "Slider" {
            $properties.Add([ObservableProperty]@{Name="Minimum"; Value=$control.Minimum})
            $properties.Add([ObservableProperty]@{Name="Maximum"; Value=$control.Maximum})
            $properties.Add([ObservableProperty]@{Name="Value"; Value=$control.Value})
            $properties.Add([ObservableProperty]@{Name="IsSnapToTickEnabled"; Value=$control.IsSnapToTickEnabled})
            $properties.Add([ObservableProperty]@{Name="TickFrequency"; Value=$control.TickFrequency})
            $properties.Add([ObservableProperty]@{Name="ValueChanged"; Value="Add_ValueChanged"})
        }
        "ProgressBar" {
            $properties.Add([ObservableProperty]@{Name="Minimum"; Value=$control.Minimum})
            $properties.Add([ObservableProperty]@{Name="Maximum"; Value=$control.Maximum})
            $properties.Add([ObservableProperty]@{Name="Value"; Value=$control.Value})
            $properties.Add([ObservableProperty]@{Name="IsIndeterminate"; Value=$control.IsIndeterminate})
        }
        "DatePicker" {
            $properties.Add([ObservableProperty]@{Name="SelectedDate"; Value=$control.SelectedDate})
            $properties.Add([ObservableProperty]@{Name="DisplayDateStart"; Value=$control.DisplayDateStart})
            $properties.Add([ObservableProperty]@{Name="DisplayDateEnd"; Value=$control.DisplayDateEnd})
            $properties.Add([ObservableProperty]@{Name="SelectedDateChanged"; Value="Add_SelectedDateChanged"})
        }
        "PasswordBox" {
            $properties.Add([ObservableProperty]@{Name="Password"; Value=$control.Password})
            $properties.Add([ObservableProperty]@{Name="PasswordChanged"; Value="Add_PasswordChanged"})
        }
        "RichTextBox" {
            $properties.Add([ObservableProperty]@{Name="Text"; Value=$control.Document.Blocks | ForEach-Object { $_.Text } -join "`n"})
            $properties.Add([ObservableProperty]@{Name="IsReadOnly"; Value=$control.IsReadOnly})
            $properties.Add([ObservableProperty]@{Name="TextChanged"; Value="Add_TextChanged"})
        }
    }

    return $properties
}

function Get-ControlEvents($control) {
    $events = New-Object System.Collections.ObjectModel.ObservableCollection[ObservableProperty]

    # Common events for all controls
    $events.Add([ObservableProperty]@{Name="Loaded"; Value=""})
    $events.Add([ObservableProperty]@{Name="Unloaded"; Value=""})
    $events.Add([ObservableProperty]@{Name="SizeChanged"; Value=""})

    # Control-specific events
    switch ($control.GetType().Name) {
        "Button" { 
            $events.Add([ObservableProperty]@{Name="Click"; Value=""})
        }
        "TextBox" { 
            $events.Add([ObservableProperty]@{Name="TextChanged"; Value=""})
            $events.Add([ObservableProperty]@{Name="KeyDown"; Value=""})
        }
        "ComboBox" { 
            $events.Add([ObservableProperty]@{Name="SelectionChanged"; Value=""})
        }
        "CheckBox" {
            $events.Add([ObservableProperty]@{Name="Checked"; Value=""})
            $events.Add([ObservableProperty]@{Name="Unchecked"; Value=""})
        }
        "RadioButton" {
            $events.Add([ObservableProperty]@{Name="Checked"; Value=""})
        }
        "ListBox" {
            $events.Add([ObservableProperty]@{Name="SelectionChanged"; Value=""})
        }
        "Slider" {
            $events.Add([ObservableProperty]@{Name="ValueChanged"; Value=""})
        }
        "DatePicker" {
            $events.Add([ObservableProperty]@{Name="SelectedDateChanged"; Value=""})
        }
        "PasswordBox" {
            $events.Add([ObservableProperty]@{Name="PasswordChanged"; Value=""})
        }
        "RichTextBox" {
            $events.Add([ObservableProperty]@{Name="TextChanged"; Value=""})
        }
    }

    # Set the Value to "Edit" for events that have handlers
    if ($control.Tag -is [Hashtable]) {
        foreach ($event in $events) {
            if ($control.Tag.ContainsKey($event.Name)) {
                $event.Value = "Edit"
            }
        }
    }

    return $events
}

function Select-Control {
    param($control)

    End-ResizeMode
    $global:selectedControl = $control
    $script:propertiesGrid.ItemsSource = Get-ControlProperties $control
    $script:eventsGrid.ItemsSource = Get-ControlEvents $control

    # Update the Events tab with saved event handlers
    if ($control.Tag -is [Hashtable]) {
        $events = $script:eventsGrid.ItemsSource
        foreach ($event in $events) {
            if ($control.Tag.ContainsKey($event.Name)) {
                $event.Value = "Edit"  # or any other indicator that an event handler exists
            } else {
                $event.Value = ""
            }
        }
        $script:eventsGrid.Items.Refresh()
    }

    # Update the selection border
    Update-SelectionBorder $control
}

function Edit-EventHandler {
    param($eventName)

    $eventHandler = $global:selectedControl.Tag.$eventName
    if (-not $eventHandler) {
        $eventHandler = "param(`$sender, `$e)`n`n# Add your code here"
    }

    $dialog = New-Object System.Windows.Window
    $dialog.Title = "Edit $eventName Event Handler"
    $dialog.Width = 800
    $dialog.Height = 600
    $dialog.WindowStartupLocation = "CenterScreen"
    $dialog.ResizeMode = "CanResizeWithGrip"

    $mainPanel = New-Object System.Windows.Controls.Grid
    $mainPanel.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition))
    $mainPanel.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{Height = "Auto"}))

    $inputBox = New-Object System.Windows.Controls.TextBox
    $inputBox.AcceptsReturn = $true
    $inputBox.AcceptsTab = $true
    $inputBox.VerticalScrollBarVisibility = "Auto"
    $inputBox.HorizontalScrollBarVisibility = "Auto"
    $inputBox.FontFamily = "Consolas"
    $inputBox.FontSize = 14
    $inputBox.Text = $eventHandler
    $inputBox.Margin = New-Object System.Windows.Thickness(10)
    [System.Windows.Controls.Grid]::SetRow($inputBox, 0)
    $mainPanel.Children.Add($inputBox)

    $buttonPanel = New-Object System.Windows.Controls.StackPanel
    $buttonPanel.Orientation = "Horizontal"
    $buttonPanel.HorizontalAlignment = "Right"
    $buttonPanel.Margin = New-Object System.Windows.Thickness(10)
    [System.Windows.Controls.Grid]::SetRow($buttonPanel, 1)

    $okButton = New-Object System.Windows.Controls.Button
    $okButton.Content = "OK"
    $okButton.Width = 75
    $okButton.Margin = New-Object System.Windows.Thickness(0, 0, 10, 0)
    $okButton.Add_Click({
        $dialog.DialogResult = $true
        $dialog.Close()
    })
    $buttonPanel.Children.Add($okButton)

    $cancelButton = New-Object System.Windows.Controls.Button
    $cancelButton.Content = "Cancel"
    $cancelButton.Width = 75
    $cancelButton.Add_Click({
        $dialog.DialogResult = $false
        $dialog.Close()
    })
    $buttonPanel.Children.Add($cancelButton)

    $mainPanel.Children.Add($buttonPanel)

    $dialog.Content = $mainPanel

    $result = $dialog.ShowDialog()

    if ($result) {
        if (-not $global:selectedControl.Tag) {
            $global:selectedControl.Tag = @{}
        }
        $global:selectedControl.Tag[$eventName] = $inputBox.Text

        # Update the Events grid
        $events = $script:eventsGrid.ItemsSource
        $event = $events | Where-Object { $_.Name -eq $eventName }
        if ($event) {
            $event.Value = "Edit"
        }
        $script:eventsGrid.Items.Refresh()

        # Compile and attach the event handler
        $scriptBlock = [ScriptBlock]::Create($inputBox.Text)
        $global:selectedControl."Add_$eventName"($scriptBlock)
    }
}

function Make-DraggableAndSelectable {
    param($control)

    $control.AddHandler(
        [System.Windows.Controls.Control]::PreviewMouseLeftButtonDownEvent,
        [System.Windows.Input.MouseButtonEventHandler]{
            param($sender, $e)
            End-ResizeMode
            Select-Control $sender
            $global:isDragging = $true
            $global:lastMousePos = [System.Windows.Input.Mouse]::GetPosition($script:designCanvas)
            $sender.CaptureMouse()
            $e.Handled = $true
        }
    )

    $control.AddHandler(
        [System.Windows.Controls.Control]::PreviewMouseMoveEvent,
        [System.Windows.Input.MouseEventHandler]{
            param($sender, $e)
            if ($global:isDragging -and $sender -eq $global:selectedControl) {
                $currentPos = [System.Windows.Input.Mouse]::GetPosition($script:designCanvas)
                $offset = New-Object System.Windows.Vector(
                    ($currentPos.X - $global:lastMousePos.X),
                    ($currentPos.Y - $global:lastMousePos.Y)
                )

                Move-Control $sender $offset

                $global:lastMousePos = $currentPos
                Update-SelectionBorder $sender
                $e.Handled = $true
            }
        }
    )

    $control.AddHandler(
        [System.Windows.Controls.Control]::PreviewMouseLeftButtonUpEvent,
        [System.Windows.Input.MouseButtonEventHandler]{
            param($sender, $e)
            if ($global:isDragging) {
                $global:isDragging = $false
                $sender.ReleaseMouseCapture()
                $e.Handled = $true
            }
        }
    )
}

function Add-ResizeHandlers {
    param($border, $control)

    $handles = $border.Children | Where-Object { $_ -is [System.Windows.Shapes.Ellipse] }
    foreach ($handle in $handles) {
        $handle.AddHandler(
            [System.Windows.Shapes.Ellipse]::PreviewMouseLeftButtonDownEvent,
            [System.Windows.Input.MouseButtonEventHandler]{
                param($sender, $e)
                $global:isResizing = $true
                $global:resizeMode = $sender.Tag
                $global:lastMousePos = [System.Windows.Input.Mouse]::GetPosition($script:designCanvas)
                $script:designCanvas.CaptureMouse()
                $e.Handled = $true
            }
        )
    }

    $script:designCanvas.AddHandler(
        [System.Windows.Controls.Canvas]::PreviewMouseMoveEvent,
        [System.Windows.Input.MouseEventHandler]{
            param($sender, $e)
            if ($global:isResizing -and $global:resizeMode -ne "None" -and $global:selectedControl -ne $null) {
                $currentPos = [System.Windows.Input.Mouse]::GetPosition($script:designCanvas)
                $offset = New-Object System.Windows.Vector(
                    ($currentPos.X - $global:lastMousePos.X),
                    ($currentPos.Y - $global:lastMousePos.Y)
                )

                Resize-Control $global:selectedControl $offset $global:resizeMode

                $global:lastMousePos = $currentPos
                Update-SelectionBorder $global:selectedControl
                $e.Handled = $true
            }
        }
    )

    $script:designCanvas.AddHandler(
        [System.Windows.Controls.Canvas]::PreviewMouseLeftButtonUpEvent,
        [System.Windows.Input.MouseButtonEventHandler]{
            param($sender, $e)
            if ($global:isResizing) {
                End-ResizeMode
                $e.Handled = $true
            }
        }
    )
}

function Get-ResizeMode {
    param($control, $mousePos)
    $threshold = 5
    $left = [System.Windows.Controls.Canvas]::GetLeft($control)
    $top = [System.Windows.Controls.Canvas]::GetTop($control)
    $right = $left + $control.ActualWidth
    $bottom = $top + $control.ActualHeight

    $isLeft = [Math]::Abs($mousePos.X - $left) -lt $threshold
    $isRight = [Math]::Abs($mousePos.X - $right) -lt $threshold
    $isTop = [Math]::Abs($mousePos.Y - $top) -lt $threshold
    $isBottom = [Math]::Abs($mousePos.Y - $bottom) -lt $threshold

    if ($isLeft -and $isTop) { return "TopLeft" }
    if ($isRight -and $isTop) { return "TopRight" }
    if ($isLeft -and $isBottom) { return "BottomLeft" }
    if ($isRight -and $isBottom) { return "BottomRight" }
    if ($isLeft) { return "Left" }
    if ($isRight) { return "Right" }
    if ($isTop) { return "Top" }
    if ($isBottom) { return "Bottom" }
    return "None"
}

function Move-Control {
    param($control, $offset)
    $newLeft = [System.Windows.Controls.Canvas]::GetLeft($control) + $offset.X
    $newTop = [System.Windows.Controls.Canvas]::GetTop($control) + $offset.Y

    if ($script:snapToGrid) {
        $gridSize = 10
        $newLeft = [Math]::Round($newLeft / $gridSize) * $gridSize
        $newTop = [Math]::Round($newTop / $gridSize) * $gridSize
    }

    [System.Windows.Controls.Canvas]::SetLeft($control, $newLeft)
    [System.Windows.Controls.Canvas]::SetTop($control, $newTop)
    Update-ControlProperties "Left" $newLeft
    Update-ControlProperties "Top" $newTop
}

function Resize-Control {
    param($control, $offset, $resizeMode)
    
    if ($null -eq $control) {
        Write-Host "Error: Control is null in Resize-Control"
        return
    }

    try {
        $left = [System.Windows.Controls.Canvas]::GetLeft($control)
        $top = [System.Windows.Controls.Canvas]::GetTop($control)
        $width = $control.ActualWidth
        $height = $control.ActualHeight

        switch ($resizeMode) {
            "Left" { 
                $width = [Math]::Max($width - $offset.X, 10)
                $left += $offset.X
            }
            "Right" { $width = [Math]::Max($width + $offset.X, 10) }
            "Top" { 
                $height = [Math]::Max($height - $offset.Y, 10)
                $top += $offset.Y
            }
            "Bottom" { $height = [Math]::Max($height + $offset.Y, 10) }
            "TopLeft" { 
                $width = [Math]::Max($width - $offset.X, 10)
                $left += $offset.X
                $height = [Math]::Max($height - $offset.Y, 10)
                $top += $offset.Y
            }
            "TopRight" { 
                $width = [Math]::Max($width + $offset.X, 10)
                $height = [Math]::Max($height - $offset.Y, 10)
                $top += $offset.Y
            }
            "BottomLeft" { 
                $width = [Math]::Max($width - $offset.X, 10)
                $left += $offset.X
                $height = [Math]::Max($height + $offset.Y, 10)
            }
            "BottomRight" { 
                $width = [Math]::Max($width + $offset.X, 10)
                $height = [Math]::Max($height + $offset.Y, 10)
            }
        }

        [System.Windows.Controls.Canvas]::SetLeft($control, $left)
        [System.Windows.Controls.Canvas]::SetTop($control, $top)
        $control.Width = $width
        $control.Height = $height

        Update-ControlProperties $control "Left" $left
        Update-ControlProperties $control "Top" $top
        Update-ControlProperties $control "Width" $width
        Update-ControlProperties $control "Height" $height
    }
    catch {
        Write-Host "Error in Resize-Control: $_"
    }
}

function Update-ControlProperties {
    param($propertyName, $propertyValue)

    if ($null -ne $script:selectedControl) {
        switch ($propertyName) {
            "Name" { $script:selectedControl.Name = $propertyValue }
            "Width" { $script:selectedControl.Width = [double]::Parse($propertyValue) }
            "Height" { $script:selectedControl.Height = [double]::Parse($propertyValue) }
            "Left" { [System.Windows.Controls.Canvas]::SetLeft($script:selectedControl, [double]::Parse($propertyValue)) }
            "Top" { [System.Windows.Controls.Canvas]::SetTop($script:selectedControl, [double]::Parse($propertyValue)) }
            "Visibility" { $script:selectedControl.Visibility = [System.Windows.Visibility]$propertyValue }
            "IsEnabled" { $script:selectedControl.IsEnabled = [System.Convert]::ToBoolean($propertyValue) }
            "Opacity" { $script:selectedControl.Opacity = [double]::Parse($propertyValue) }
            "ToolTip" { $script:selectedControl.ToolTip = $propertyValue }
            "Content" { 
                if ($script:selectedControl -is [System.Windows.Controls.ContentControl]) {
                    $script:selectedControl.Content = $propertyValue
                }
            }
            "Text" { 
                if ($script:selectedControl -is [System.Windows.Controls.TextBox]) {
                    $script:selectedControl.Text = $propertyValue
                }
                elseif ($script:selectedControl -is [System.Windows.Controls.RichTextBox]) {
                    $script:selectedControl.Document.Blocks.Clear()
                    $script:selectedControl.Document.Blocks.Add((New-Object System.Windows.Documents.Paragraph (New-Object System.Windows.Documents.Run $propertyValue)))
                }
            }
            "FontSize" { $script:selectedControl.FontSize = [double]::Parse($propertyValue) }
            "FontWeight" { $script:selectedControl.FontWeight = [System.Windows.FontWeight]::FromOpenTypeWeight([int]::Parse($propertyValue)) }
            "Background" { $script:selectedControl.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString($propertyValue) }
            "Foreground" { $script:selectedControl.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString($propertyValue) }
            "SelectedIndex" { 
                if ($script:selectedControl -is [System.Windows.Controls.Selector]) {
                    $script:selectedControl.SelectedIndex = [int]::Parse($propertyValue)
                }
            }
            "Items" {
                if ($script:selectedControl -is [System.Windows.Controls.ItemsControl]) {
                    $script:selectedControl.Items.Clear()
                    $propertyValue.Split(',') | ForEach-Object { $script:selectedControl.Items.Add($_.Trim()) }
                }
            }
            "IsChecked" {
                if ($script:selectedControl -is [System.Windows.Controls.Primitives.ToggleButton]) {
                    $script:selectedControl.IsChecked = [System.Convert]::ToBoolean($propertyValue)
                }
            }
            "GroupName" {
                if ($script:selectedControl -is [System.Windows.Controls.RadioButton]) {
                    $script:selectedControl.GroupName = $propertyValue
                }
            }
            "Minimum" {
                if ($script:selectedControl -is [System.Windows.Controls.Primitives.RangeBase]) {
                    $script:selectedControl.Minimum = [double]::Parse($propertyValue)
                }
            }
            "Maximum" {
                if ($script:selectedControl -is [System.Windows.Controls.Primitives.RangeBase]) {
                    $script:selectedControl.Maximum = [double]::Parse($propertyValue)
                }
            }
            "Value" {
                if ($script:selectedControl -is [System.Windows.Controls.Primitives.RangeBase]) {
                    $script:selectedControl.Value = [double]::Parse($propertyValue)
                }
            }
            "IsSnapToTickEnabled" {
                if ($script:selectedControl -is [System.Windows.Controls.Slider]) {
                    $script:selectedControl.IsSnapToTickEnabled = [System.Convert]::ToBoolean($propertyValue)
                }
            }
            "TickFrequency" {
                if ($script:selectedControl -is [System.Windows.Controls.Slider]) {
                    $script:selectedControl.TickFrequency = [double]::Parse($propertyValue)
                }
            }
            "IsIndeterminate" {
                if ($script:selectedControl -is [System.Windows.Controls.ProgressBar]) {
                    $script:selectedControl.IsIndeterminate = [System.Convert]::ToBoolean($propertyValue)
                }
            }
            "SelectedDate" {
                if ($script:selectedControl -is [System.Windows.Controls.DatePicker]) {
                    $script:selectedControl.SelectedDate = [DateTime]::Parse($propertyValue)
                }
            }
            "DisplayDateStart" {
                if ($script:selectedControl -is [System.Windows.Controls.DatePicker]) {
                    $script:selectedControl.DisplayDateStart = [DateTime]::Parse($propertyValue)
                }
            }
            "DisplayDateEnd" {
                if ($script:selectedControl -is [System.Windows.Controls.DatePicker]) {
                    $script:selectedControl.DisplayDateEnd = [DateTime]::Parse($propertyValue)
                }
            }
            "Password" {
                if ($script:selectedControl -is [System.Windows.Controls.PasswordBox]) {
                    $script:selectedControl.Password = $propertyValue
                }
            }
            "IsReadOnly" {
                if ($script:selectedControl -is [System.Windows.Controls.TextBoxBase]) {
                    $script:selectedControl.IsReadOnly = [System.Convert]::ToBoolean($propertyValue)
                }
            }
        }
        
        # Update the properties grid
        $properties = $script:propertiesGrid.ItemsSource
        $property = $properties | Where-Object { $_.Name -eq $propertyName }
        if ($property) {
            $property.Value = $propertyValue
        }

        # Update the selection border
        Update-SelectionBorder $script:selectedControl
    }
}

function Update-GridLines {
    $gridLines = $script:designCanvas.Children | Where-Object { $_.Tag -eq "GridLine" }
    foreach ($line in $gridLines) {
        $script:designCanvas.Children.Remove($line)
    }

    if ($script:snapToGrid) {
        $gridSize = 10
        $canvasWidth = $script:designCanvas.ActualWidth
        $canvasHeight = $script:designCanvas.ActualHeight

        for ($x = 0; $x -lt $canvasWidth; $x += $gridSize) {
            for ($y = 0; $y -lt $canvasHeight; $y += $gridSize) {
                $ellipse = New-Object System.Windows.Shapes.Ellipse
                $ellipse.Width = 1
                $ellipse.Height = 1
                $ellipse.Fill = [System.Windows.Media.Brushes]::LightGray
                $ellipse.Tag = "GridLine"
                [System.Windows.Controls.Canvas]::SetLeft($ellipse, $x)
                [System.Windows.Controls.Canvas]::SetTop($ellipse, $y)
                $script:designCanvas.Children.Add($ellipse)
            }
        }
    }
}