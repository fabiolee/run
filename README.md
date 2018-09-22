# Run

Cari Runners blog reader mobile apps written in Flutter.

## Setup

### Android

Create a `android/app/fabric.properties` file and include your own Fabric `apiKey` and `apiSecret`.
Example:
```
apiKey=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
apiSecret=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

Create a `android/app/google-services.json` file to include your own Firebase.

Create a `android/cert/keystore.properties` file and include your own keystore storeFile, storePassword, keyAlias and keyPassword.
Example:
```
storeFile=../cert/keystore.jks
storePassword=xxxxxxxx
keyAlias=xxxxxxxx
keyPassword=xxxxxxxx
```

### iOS

Create a `ios/Runner/GoogleService-Info.plist` files to include your own Firebase.

## Screenshots

### Android

![Page](art/android/Page.png)
![Search](art/android/Search.png)
![Post](art/android/Post.png)
![Favorites](art/android/Favorites.png)
![Settings](art/android/Settings.png)
![Push Notification](art/android/PushNotification.png)

### iOS

![Page](art/ios/Page.JPG)
![Search](art/ios/Search.JPG)
![Post](art/ios/Post.png)
![Favorites](art/ios/Favorites.png)
![Settings](art/ios/Settings.png)
![Push Notification](art/ios/PushNotification.png)
