import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const tajiSecureStorage = FlutterSecureStorage(
  aOptions: AndroidOptions(storageNamespace: 'taji_auth'),
  iOptions: IOSOptions(
    accountName: 'taji_auth',
    accessibility: KeychainAccessibility.first_unlock_this_device,
  ),
  mOptions: MacOsOptions(
    accountName: 'taji_auth',
    accessibility: KeychainAccessibility.first_unlock_this_device,
  ),
);
