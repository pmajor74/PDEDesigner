try {
    Add-Type -TypeDefinition @"
    using System;
    using System.ComponentModel;

    public class ObservableProperty : INotifyPropertyChanged
    {
        private string _name;
        private object _value;

        public string Name
        {
            get { return _name; }
            set
            {
                if (_name != value)
                {
                    _name = value;
                    OnPropertyChanged("Name");
                }
            }
        }

        public object Value
        {
            get { return _value; }
            set
            {
                if (_value != value)
                {
                    _value = value;
                    OnPropertyChanged("Value");
                }
            }
        }

        public event PropertyChangedEventHandler PropertyChanged;

        protected virtual void OnPropertyChanged(string propertyName)
        {
            PropertyChangedEventHandler handler = PropertyChanged;
            if (handler != null)
            {
                handler(this, new PropertyChangedEventArgs(propertyName));
            }
        }
    }
"@
} catch {
    if (-not $_.Exception.Message.Contains("The type name 'ObservableProperty' already exists")) {
        throw
    }
}