// import 'dart:io';

// import 'package:flutter_downloader/flutter_downloader.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:permission_handler/permission_handler.dart';


// downloadFile(String url) async {
//   await Permission.storage.request();
//   var appPath = await getTemporaryDirectory();
//   var path = Directory('storage/emulated/0/alarm');

//   if (await path.exists() == true) {
//   } else {
//     await path.create(recursive: true);
//   }
//   final taskId = await FlutterDownloader.enqueue(
//     url: url,
//     savedDir: 'storage/emulated/0/quraan',
//     showNotification:
//         true, 
//     openFileFromNotification:
//         true,
//   );

// }

// File checkIfExist(String url){
//   final fileName = url.substring(url.lastIndexOf('/') + 1);
//     var path = Directory('storage/emulated/0/alarm/');
//     String pathFile = path.path + fileName;
//     return File(pathFile);
// }