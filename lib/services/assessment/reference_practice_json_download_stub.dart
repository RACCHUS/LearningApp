/// Non-web builds: do not misrepresent writing into an app-private directory
/// as a user-accessible exported file. Clipboard copying remains available.
const bool isSupported = false;

void requestDownload({required String filename, required String json}) {
  throw UnsupportedError('JSON file download is supported in browsers only');
}
