import 'dart:convert';
import 'dart:async';
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/io.dart';
import 'package:progress_indicators/progress_indicators.dart';
import 'package:event_bus/event_bus.dart';
import 'package:flutter/widgets.dart';

part 'settings.dart';
part 'data_model.dart';

EventBus eventBus = new EventBus();
const String appName = "HA Client";
const appVersion = "0.0.11-alpha";

void main() => runApp(new HassClientApp());

class HassClientApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      title: appName,
      theme: new ThemeData(
        primarySwatch: Colors.blue,
      ),
      initialRoute: "/",
      routes: {
        "/": (context) => MainPage(title: 'Hass Client'),
        "/connection-settings": (context) => ConnectionSettingsPage(title: "Connection Settings")
      },
    );
  }
}

class MainPage extends StatefulWidget {
  MainPage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MainPageState createState() => new _MainPageState();
}

class _MainPageState extends State<MainPage> with WidgetsBindingObserver {
  HassioDataModel _dataModel;
  Map _entitiesData;
  Map _uiStructure;
  Map _instanceConfig;
  int _uiViewsCount = 0;
  String _instanceHost;
  int _errorCodeToBeShown = 0;
  String _lastErrorMessage = "";
  StreamSubscription _stateSubscription;
  StreamSubscription _settingsSubscription;
  bool _isLoading = true;
  Map _stateIconColors = {
    "on": Colors.amber,
    "off": Colors.blueGrey,
    "unavailable": Colors.black12,
    "unknown": Colors.black12,
    "playing": Colors.amber
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _settingsSubscription = eventBus.on<SettingsChangedEvent>().listen((event) {
      debugPrint("Settings change event: reconnect=${event.reconnect}");
      setState(() {
        _errorCodeToBeShown = 0;
      });
      _initConnection();
    });
    _initConnection();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint("$state");
    if (state == AppLifecycleState.resumed) {
      _refreshData();
    }
  }

  _initConnection() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String domain = prefs.getString('hassio-domain');
    String port = prefs.getString('hassio-port');
    _instanceHost = "$domain:$port";
    String apiEndpoint = "${prefs.getString('hassio-protocol')}://$domain:$port/api/websocket";
    String apiPassword = prefs.getString('hassio-password');
    String authType = prefs.getString('hassio-auth-type');
    if ((domain == null) || (port == null) || (apiPassword == null) ||
        (domain.length == 0) || (port.length == 0) || (apiPassword.length == 0)) {
      setState(() {
        _errorCodeToBeShown = 5;
      });
    } else {
      if (_dataModel != null) _dataModel.closeConnection();
      _createConnection(apiEndpoint, apiPassword, authType);
    }
  }

  _createConnection(String apiEndpoint, String apiPassword, String authType) {
    _dataModel = HassioDataModel(apiEndpoint, apiPassword, authType);
    _refreshData();
    if (_stateSubscription != null) _stateSubscription.cancel();
    _stateSubscription = eventBus.on<StateChangedEvent>().listen((event) {
      debugPrint("State change event for ${event.entityId}");
      setState(() {
        _entitiesData = _dataModel.entities;
      });
    });
  }

  _refreshData() async {
    setState(() {
      _isLoading = true;
    });
    _errorCodeToBeShown = 0;
    if (_dataModel != null) {
      await _dataModel.fetch().then((result) {
        setState(() {
          _instanceConfig = _dataModel.instanceConfig;
          _entitiesData = _dataModel.entities;
          _uiStructure = _dataModel.uiStructure;
          _uiViewsCount = _uiStructure.length;
          _isLoading = false;
        });
      }).catchError((e) {
        _setErrorState(e);
      });
    }
  }

  _setErrorState(e) {
    setState(() {
      _errorCodeToBeShown = e["errorCode"] != null ? e["errorCode"] : 99;
      _lastErrorMessage = e["errorMessage"] ?? "Unknown error";
      _isLoading = false;
    });
  }

  void _callService(String domain, String service, String entityId) {
    setState(() {
      _isLoading = true;
    });
    _dataModel.callService(domain, service, entityId).then((r) {
      setState(() {
        _isLoading = false;
      });
    }).catchError((e) => _setErrorState(e));
  }

  List<Widget> _buildViews() {
    List<Widget> result = [];
    if ((_entitiesData != null) && (_uiStructure != null)) {
      _uiStructure.forEach((viewId, structure) {
        result.add(
            RefreshIndicator(
              color: Colors.amber,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: _buildSingleView(structure),
              ),
              onRefresh: () => _refreshData(),
            )
        );
      });
    }
    return result;
  }

  List<Widget> _buildSingleView(structure) {
    List<Widget> result = [];
    /*structure["standalone"].forEach((entityId) {
        result.add(_buildCard([entityId], ""));
      });*/
    structure["groups"].forEach((id, group) {
      if (group["children"].length > 0) {
        result.add(_buildCard(
            group["children"], group["friendly_name"].toString()));
      }
    });

    return result;
  }

  Card _buildCard(List ids, String name) {
    List<Widget> body = [];
    body.add(_buildCardHeader(name));
    body.addAll(_buildCardBody(ids));
    Card result =
    Card(child: new Column(mainAxisSize: MainAxisSize.min, children: body));
    return result;
  }

  Widget _buildCardHeader(String name) {
    var result;
    if (name.length > 0) {
      result = new ListTile(
        //leading: const Icon(Icons.device_hub),
        //subtitle: Text(".."),
        //trailing: Text("${data["state"]}"),
        title: Text("$name",
            textAlign: TextAlign.left,
            overflow: TextOverflow.ellipsis,
            style: new TextStyle(fontWeight: FontWeight.bold, fontSize: 25.0)),
      );
    } else {
      result = new Container(width: 0.0, height: 0.0);
    }
    return result;
  }

  List<Widget> _buildCardBody(List ids) {
    List<Widget> entities = [];
    ids.forEach((id) {
      var data = _entitiesData[id];
      if (data == null) {
        debugPrint("Hiding unknown entity from card: $id");
      } else {
        entities.add(new ListTile(
          leading: Icon(
            _createMDIfromCode(data["iconCode"]),
            color: _stateIconColors[data["state"]] ?? Colors.blueGrey,
          ),
          //subtitle: Text("${data['entity_id']}"),
          trailing: _buildEntityAction(id),
          title: Text(
            "${data["display_name"]}",
            overflow: TextOverflow.ellipsis,
          ),
        ));
      }
    });
    return entities;
  }

  Widget _buildEntityAction(String entityId) {
    var entity = _entitiesData[entityId];
    Widget result;
    if (entity["actionType"] == "switch") {
      result = Switch(
        value: (entity["state"] == "on"),
        onChanged: ((state) {
          _callService(
              entity["domain"], state ? "turn_on" : "turn_off", entityId);
          setState(() {
            _entitiesData[entityId]["state"] = state ? "on" : "off";
          });
        }),
      );
    } else if (entity["actionType"] == "statelessIcon") {
      result = SizedBox(
          width: 60.0,
          child: FlatButton(
            onPressed: (() {
              _callService(entity["domain"], "turn_on", entityId);
            }),
            child: Text(
              "Run",
              textAlign: TextAlign.right,
              style: new TextStyle(fontSize: 16.0, color: Colors.blue),
            ),
          ));
    } else {
      result = Padding(
          padding: EdgeInsets.fromLTRB(0.0, 0.0, 16.0, 0.0),
          child: Text(
              "${entity["state"]}${(entity["attributes"] != null && entity["attributes"]["unit_of_measurement"] != null) ? entity["attributes"]["unit_of_measurement"] : ''}",
              textAlign: TextAlign.right,
              style: new TextStyle(
                fontSize: 16.0,
              )));
    }
    /*return SizedBox(
      width: 60.0,
      // height: double.infinity,
      child: result
    );*/
    return result;
  }

  IconData _createMDIfromCode(int code) {
    return IconData(code, fontFamily: 'Material Design Icons');
  }

  List<Tab> buildUIViewTabs() {
    List<Tab> result = [];
    if ((_entitiesData != null) && (_uiStructure != null)) {
      _uiStructure.forEach((viewId, structure) {
        result.add(
            Tab(
                icon: Icon(_createMDIfromCode(structure["iconCode"]))
            )
        );
      });
    }
    return result;
  }

  Widget _buildAppTitle() {
    Row titleRow = Row(
      children: [Text(_instanceConfig != null ? _instanceConfig["location_name"] : "")],
    );
    if (_isLoading) {
      titleRow.children.add(Padding(
        child: JumpingDotsProgressIndicator(
          fontSize: 26.0,
          color: Colors.white,
        ),
        padding: const EdgeInsets.fromLTRB(5.0, 0.0, 0.0, 30.0),
      ));
    }
    return titleRow;
  }

  Drawer _buildAppDrawer() {
    return new Drawer(
      child: ListView(
        children: <Widget>[
          new UserAccountsDrawerHeader(
            accountName: Text(_instanceConfig != null ? _instanceConfig["location_name"] : "Unknown"),
            accountEmail: Text(_instanceHost ?? "Not configured"),
            currentAccountPicture: new Image.asset('images/hassio-192x192.png'),
          ),
          new ListTile(
            leading: Icon(Icons.settings),
            title: Text("Connection settings"),
            onTap: () {
              Navigator.pushNamed(context, '/connection-settings');
            },
          ),
          new AboutListTile(
            applicationName: appName,
            applicationVersion: appVersion,
            applicationLegalese: "Keyboard Crumbs | www.keyboardcrumbs.io",
          )
        ],
      ),
    );
  }

  _checkShowInfo(BuildContext context) {
    if (_errorCodeToBeShown > 0) {
      String message = _lastErrorMessage;
      SnackBarAction action;
      switch (_errorCodeToBeShown) {
        case 1: {
            action = SnackBarAction(
                label: "Retry",
                onPressed: () {
                  _scaffoldKey?.currentState?.hideCurrentSnackBar();
                  _refreshData();
                },
            );
            break;
          }

        case 5: {
          message = "Check connection settings";
          action = SnackBarAction(
            label: "Open",
            onPressed: () {
              _scaffoldKey?.currentState?.hideCurrentSnackBar();
              Navigator.pushNamed(context, '/connection-settings');
            },
          );
          break;
        }

        case 6: {
          action = SnackBarAction(
            label: "Settings",
            onPressed: () {
              _scaffoldKey?.currentState?.hideCurrentSnackBar();
              Navigator.pushNamed(context, '/connection-settings');
            },
          );
          break;
        }

        case 7: {
          action = SnackBarAction(
            label: "Retry",
            onPressed: () {
              _scaffoldKey?.currentState?.hideCurrentSnackBar();
              _refreshData();
            },
          );
          break;
        }

        case 8: {
          action = SnackBarAction(
            label: "Reconnect",
            onPressed: () {
              _scaffoldKey?.currentState?.hideCurrentSnackBar();
              _refreshData();
            },
          );
          break;
        }
      }
      Timer(Duration(seconds: 1), () {
        _scaffoldKey.currentState.hideCurrentSnackBar();
        _scaffoldKey.currentState.showSnackBar(
            SnackBar(
                content: Text("$message (code: $_errorCodeToBeShown)"),
                action: action,
                duration: Duration(hours: 1),
            )
        );
      });
    } else {
      _scaffoldKey?.currentState?.hideCurrentSnackBar();
    }
  }

  final GlobalKey<ScaffoldState> _scaffoldKey = new GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    _checkShowInfo(context);
    // This method is rerun every time setState is called.
    //
    if (_entitiesData == null) {
      return new Scaffold(
        key: _scaffoldKey,
        appBar: new AppBar(
          title: _buildAppTitle()
        ),
        drawer: _buildAppDrawer(),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              /*Padding(
                padding: EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 10.0),
                child: Text(
                    _fetchErrorCode > 0 ? "Well... no.\n\nThere was an error [$_fetchErrorCode]: ${_getErrorMessageByCode(_fetchErrorCode, false)}" : "Loading...",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16.0),
                ),
              ),*/
              Icon(
                _createMDIfromCode(MaterialDesignIcons.getCustomIconByName("mdi:home-assistant")),
                size: 100.0,
                color: _errorCodeToBeShown == 0 ? Colors.blue : Colors.redAccent,
              ),
            ]
          ),
        ),
        floatingActionButton: new FloatingActionButton(
          onPressed: _refreshData,
          tooltip: 'Increment',
          child: new Icon(Icons.refresh),
        ),
      );
    } else {
      return DefaultTabController(
          length: _uiViewsCount,
          child: new Scaffold(
            key: _scaffoldKey,
            appBar: new AppBar(
              // Here we take the value from the MyHomePage object that was created by
              // the App.build method, and use it to set our appbar title.
              title: _buildAppTitle(),
              bottom: TabBar(
                  tabs: buildUIViewTabs()
              ),
            ),
            drawer: _buildAppDrawer(),
            body: TabBarView(
                children: _buildViews()
            ),
          )
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_stateSubscription != null) _stateSubscription.cancel();
    if (_settingsSubscription != null) _settingsSubscription.cancel();
    _dataModel.closeConnection();
    super.dispose();
  }
}
