using Windows.ApplicationModel.Activation;
using Windows.UI.Xaml;

namespace ClipSync.ShareTarget
{
    /// <summary>Windows Share contract entry point packaged beside the Flutter executable.</summary>
    sealed partial class App : Application
    {
        public App()
        {
            InitializeComponent();
        }

        protected override void OnShareTargetActivated(ShareTargetActivatedEventArgs args)
        {
            Window.Current.Content = new SharePage(args.ShareOperation);
            Window.Current.Activate();
        }
    }
}
