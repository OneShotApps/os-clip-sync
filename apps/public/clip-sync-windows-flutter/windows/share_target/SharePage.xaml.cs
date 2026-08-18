using System;
using System.Linq;
using System.Threading.Tasks;
using Windows.ApplicationModel.DataTransfer;
using Windows.ApplicationModel.DataTransfer.ShareTarget;
using Windows.Storage;
using Windows.Storage.Streams;
using Windows.System;
using Windows.UI.Xaml.Controls;

namespace ClipSync.ShareTarget
{
    /// <summary>
    /// Copies an explicitly shared value into this package's local state, then activates
    /// the Flutter application through its private protocol. No clipboard history is stored.
    /// </summary>
    public sealed partial class SharePage : Page
    {
        private readonly ShareOperation operation;

        public SharePage(ShareOperation operation)
        {
            InitializeComponent();
            this.operation = operation;
            Loaded += async (_, __) => await ReceiveAsync();
        }

        private async Task DeleteIfPresentAsync(string name)
        {
            var file = await ApplicationData.Current.LocalFolder.TryGetItemAsync(name);
            if (file != null)
            {
                await file.DeleteAsync(StorageDeleteOption.PermanentDelete);
            }
        }

        private async Task ClearPendingAsync()
        {
            await DeleteIfPresentAsync("pending-kind.txt");
            await DeleteIfPresentAsync("pending-text.txt");
            await DeleteIfPresentAsync("pending-image.bin");
            await DeleteIfPresentAsync("pending-image-mime.txt");
        }

        private async Task SaveTextAsync(string text)
        {
            var folder = ApplicationData.Current.LocalFolder;
            var textFile = await folder.CreateFileAsync(
                "pending-text.txt",
                CreationCollisionOption.ReplaceExisting
            );
            await FileIO.WriteTextAsync(textFile, text);
            var marker = await folder.CreateFileAsync(
                "pending-kind.txt",
                CreationCollisionOption.ReplaceExisting
            );
            await FileIO.WriteTextAsync(marker, "text");
        }

        private async Task SaveImageAsync(IRandomAccessStreamWithContentType stream)
        {
            var mimeType = stream.ContentType.ToLowerInvariant();
            if (mimeType != "image/png" && mimeType != "image/jpeg" && mimeType != "image/webp")
            {
                throw new InvalidOperationException("Clip Sync accepts PNG, JPEG, and WebP photos.");
            }
            var folder = ApplicationData.Current.LocalFolder;
            var imageFile = await folder.CreateFileAsync(
                "pending-image.bin",
                CreationCollisionOption.ReplaceExisting
            );
            using (var output = await imageFile.OpenAsync(FileAccessMode.ReadWrite))
            {
                await RandomAccessStream.CopyAsync(stream, output);
            }
            var mimeFile = await folder.CreateFileAsync(
                "pending-image-mime.txt",
                CreationCollisionOption.ReplaceExisting
            );
            await FileIO.WriteTextAsync(mimeFile, mimeType);
            var marker = await folder.CreateFileAsync(
                "pending-kind.txt",
                CreationCollisionOption.ReplaceExisting
            );
            await FileIO.WriteTextAsync(marker, "image");
        }

        private async Task ReceiveAsync()
        {
            try
            {
                await ClearPendingAsync();
                var data = operation.Data;
                if (data.Contains(StandardDataFormats.Text))
                {
                    await SaveTextAsync(await data.GetTextAsync());
                }
                else if (data.Contains(StandardDataFormats.Bitmap))
                {
                    var reference = await data.GetBitmapAsync();
                    await SaveImageAsync(await reference.OpenReadAsync());
                }
                else if (data.Contains(StandardDataFormats.StorageItems))
                {
                    var file = (await data.GetStorageItemsAsync()).OfType<StorageFile>().FirstOrDefault();
                    if (file == null)
                    {
                        throw new InvalidOperationException("No shared photo was available.");
                    }
                    await SaveImageAsync(await file.OpenReadAsync());
                }
                else
                {
                    throw new InvalidOperationException("Clip Sync accepts shared text or a photo.");
                }

                await Launcher.LaunchUriAsync(new Uri("clipsync-share://pending"));
                operation.ReportCompleted();
            }
            catch (Exception error)
            {
                operation.ReportError(error.Message);
            }
        }
    }
}
