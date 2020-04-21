import 'dart:convert';
import 'dart:io';

import 'package:background_fetch/background_fetch.dart';
import 'package:bottom_navigation_badge/bottom_navigation_badge.dart';
import 'package:firebase_in_app_messaging/firebase_in_app_messaging.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:package_info/package_info.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pikobar_flutter/components/DialogUpdateApp.dart';
import 'package:pikobar_flutter/constants/Analytics.dart';
import 'package:pikobar_flutter/constants/Dictionary.dart';
import 'package:pikobar_flutter/constants/NewsType.dart';
import 'package:pikobar_flutter/constants/firebaseConfig.dart';
import 'package:pikobar_flutter/environment/Environment.dart';
import 'package:pikobar_flutter/repositories/AuthRepository.dart';
import 'package:pikobar_flutter/repositories/MessageRepository.dart';
import 'package:pikobar_flutter/screens/faq/FaqScreen.dart';
import 'package:pikobar_flutter/screens/home/BackgroundServicePikobar.dart';
import 'package:pikobar_flutter/screens/home/components/HomeScreen.dart';
import 'package:pikobar_flutter/screens/messages/messages.dart';
import 'package:pikobar_flutter/screens/messages/messagesDetailSecreen.dart';
import 'package:pikobar_flutter/screens/myAccount/ProfileScreen.dart';
import 'package:pikobar_flutter/screens/news/News.dart';
import 'package:pikobar_flutter/screens/news/NewsDetailScreen.dart';
import 'package:pikobar_flutter/utilities/AnalyticsHelper.dart';
import 'package:pikobar_flutter/utilities/AnnouncementSharedPreference.dart';
import 'package:pikobar_flutter/utilities/NotificationHelper.dart';
import 'package:shared_preferences/shared_preferences.dart';

class IndexScreen extends StatefulWidget {
  @override
  IndexScreenState createState() => IndexScreenState();

}

class IndexScreenState extends State<IndexScreen> {
  FirebaseMessaging _firebaseMessaging = FirebaseMessaging();
  static FirebaseInAppMessaging firebaseInAppMsg = FirebaseInAppMessaging();

  int _currentIndex = 0;
  BackgroundServicePikobar backgroundServicePikobar = BackgroundServicePikobar();

  BottomNavigationBadge badger;
  List<BottomNavigationBarItem> items;
  int countMessage = 0;

  //variabel used for background fetch
  bool _enabled = true;
  int _status = 0;
  List<String> _events = [];

  @override
  void initState() {
    initializeDateFormatting();
    getCountMessage();
    createDirectory();
    setFlutterDownloaderInitial();
    backgroundServicePikobar.initPlatformState();

    _initializeBottomNavigationBar();
    setStatAnnouncement();
    registerFCMToken();

    _firebaseMessaging.configure(
      onMessage: (Map<String, dynamic> message) async {
        print("onMessage: $message");
        NotificationHelper().showNotification(
            message['notification']['title'], message['notification']['body'],
            payload: jsonEncode(message['data']),
            onSelectNotification: onSelectNotification);
      },
      onLaunch: (Map<String, dynamic> message) async {
        print("onLaunch: $message");
        _actionNotification(jsonEncode(message['data']));
      },
      onResume: (Map<String, dynamic> message) async {
        print("onResume: $message");
        _actionNotification(jsonEncode(message['data']));
      },
    );

//    _firebaseMessaging.getToken().then((token) => print(token));

    _firebaseMessaging.subscribeToTopic('general');

    _firebaseMessaging.requestNotificationPermissions(
        IosNotificationSettings(sound: true, badge: true, alert: true));

    firebaseInAppMsg.setAutomaticDataCollectionEnabled(true);

    super.initState();
  }

  setStatAnnouncement() async {
    await AnnouncementSharedPreference.setAnnounceScreen(true);
  }

  setFlutterDownloaderInitial() async {
    await FlutterDownloader.initialize();
  }

  createDirectory() async {
    if (Platform.isAndroid) {
      String localPath =
          (await getExternalStorageDirectory()).path + '/download';
      final publicDownloadDir = Directory(Environment.downloadStorage);
      final savedDir = Directory(localPath);
      bool hasExistedPublicDownloadDir = await publicDownloadDir.exists();
      bool hasExistedSavedDir = await savedDir.exists();
      if (!hasExistedPublicDownloadDir) {
        publicDownloadDir.create();
      }
      if (!hasExistedSavedDir) {
        savedDir.create();
      }
    }
  }

  registerFCMToken() async {
    await AuthRepository().registerFCMToken();
  }

  _initializeBottomNavigationBar() {
    badger = BottomNavigationBadge(
        backgroundColor: Colors.red,
        badgeShape: BottomNavigationBadgeShape.circle,
        textColor: Colors.white,
        position: BottomNavigationBadgePosition.topRight,
        textSize: 8);

    items = [
      BottomNavigationBarItem(
          icon: Icon(FontAwesomeIcons.home, size: 16),
          title: Column(
            children: <Widget>[
              SizedBox(height: 4),
              Text(Dictionary.home),
            ],
          )),
      BottomNavigationBarItem(
          icon: Icon(FontAwesomeIcons.solidEnvelope, size: 16),
          title: Column(
            children: <Widget>[
              SizedBox(height: 4),
              Text(Dictionary.message),
            ],
          )),
      BottomNavigationBarItem(
          icon: Icon(FontAwesomeIcons.solidQuestionCircle, size: 16),
          title: Column(
            children: <Widget>[
              SizedBox(height: 4),
              Text(Dictionary.help),
            ],
          )),
      BottomNavigationBarItem(
          icon: Icon(Icons.person),
          title: Column(
            children: <Widget>[
              Text(Dictionary.profile),
            ],
          )),
    ];
  }

  Future<void> onSelectNotification(String payload) async {
    if (payload != null) {
      debugPrint('notification payload: ' + payload);

      _actionNotification(payload);
    }
  }

  _actionNotification(String payload) {
    final data = jsonDecode(payload);
    if (data['target'] == 'news') {
      String newsType;

      switch (data['type']) {
        case NewsType.articles:
          newsType = Dictionary.latestNews;
          break;

        case NewsType.articlesNational:
          newsType = Dictionary.nationalNews;
          break;

        case NewsType.articlesWorld:
          newsType = Dictionary.worldNews;
          break;

        default:
          newsType = Dictionary.latestNews;
      }

      if (data['id'] != null && data['id'] != 'null') {
        Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => NewsDetailScreen(
                  id: data['id'],
                  news: newsType,
                  isFromNotification: true,
                )));
      } else {
        Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => News(news: newsType)));
      }
    } else if (data['target'] == 'broadcast') {
      if (data['id'] != null && data['id'] != 'null') {
        Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => MessageDetailScreen(
                  id: data['id'],
                  isFromNotification: true,
                )));
      } else {
        Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => Messages(indexScreenState: this)));
      }
    }
  }

  void onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _buildMainScaffold(context);
  }

  _buildMainScaffold(BuildContext context) {
    return Scaffold(
      body: _buildContent(_currentIndex),
      bottomNavigationBar: BottomNavigationBar(
          onTap: onTabTapped,
          currentIndex: _currentIndex,
          type: BottomNavigationBarType.fixed,
          items: items),
    );
  }

  getCountMessage() {
    Future.delayed(Duration(milliseconds: 0), () async {
      countMessage = await MessageRepository().hasUnreadData();
      setState(() {
        // ignore: unnecessary_statements
        if (countMessage <= 0) {
          items[1] = BottomNavigationBarItem(
              icon: Icon(FontAwesomeIcons.solidEnvelope, size: 16),
              title: Column(
                children: <Widget>[
                  SizedBox(height: 4),
                  Text(Dictionary.message),
                ],
              ));
        } else {
          items = badger.setBadge(items, countMessage.toString(), 1);
        }
      });
    });
  }

  Widget _buildContent(int index) {
    switch (index) {
      case 0:
        return HomeScreen();
      case 1:
        AnalyticsHelper.setLogEvent(Analytics.tappedMessage);
        return Messages(indexScreenState: this);

      case 2:
        AnalyticsHelper.setLogEvent(Analytics.tappedFaq);
        return FaqScreen();

      case 3:
        return ProfileScreen();
      default:
        return HomeScreen();
    }
  }

  @override
  void dispose() {
    BackgroundFetch.registerHeadlessTask(backgroundServicePikobar.backgroundFetchHeadlessTask);
    super.dispose();
  }
}
