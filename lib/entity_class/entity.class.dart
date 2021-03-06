part of '../main.dart';

class Entity {

  static List badgeDomains = [
    "alarm_control_panel",
    "binary_sensor",
    "device_tracker",
    "updater",
    "sun",
    "timer",
    "sensor"
  ];

  Map attributes;
  String domain;
  String entityId;
  String state;
  DateTime _lastUpdated;

  List<Entity> childEntities = [];
  List<String> attributesToShow = ["all"];
  EntityHistoryConfig historyConfig = EntityHistoryConfig(
    chartType: EntityHistoryWidgetType.simple
  );

  String get displayName =>
      attributes["friendly_name"] ?? (attributes["name"] ?? entityId.split(".")[1].replaceAll("_", " "));

  String get deviceClass => attributes["device_class"] ?? null;
  bool get isView =>
      (domain == "group") &&
      (attributes != null ? attributes["view"] ?? false : false);
  bool get isGroup => domain == "group";
  bool get isBadge => Entity.badgeDomains.contains(domain);
  String get icon => attributes["icon"] ?? "";
  bool get isOn => state == EntityState.on;
  String get entityPicture => attributes["entity_picture"];
  String get unitOfMeasurement => attributes["unit_of_measurement"] ?? "";
  List get childEntityIds => attributes["entity_id"] ?? [];
  String get lastUpdated => _getLastUpdatedFormatted();
  bool get isHidden => attributes["hidden"] ?? false;
  double get doubleState => double.tryParse(state) ?? 0.0;

  Entity(Map rawData) {
    update(rawData);
  }

  void update(Map rawData) {
    attributes = rawData["attributes"] ?? {};
    domain = rawData["entity_id"].split(".")[0];
    entityId = rawData["entity_id"];
    state = rawData["state"];
    _lastUpdated = DateTime.tryParse(rawData["last_updated"]);
  }

  double _getDoubleAttributeValue(String attributeName) {
    var temp1 = attributes["$attributeName"];
    if (temp1 is int) {
      return temp1.toDouble();
    } else if (temp1 is double) {
      return temp1;
    } else {
      return double.tryParse("$temp1");
    }
  }

  int _getIntAttributeValue(String attributeName) {
    var temp1 = attributes["$attributeName"];
    if (temp1 is int) {
      return temp1;
    } else if (temp1 is double) {
      return temp1.round();
    } else {
      return int.tryParse("$temp1");
    }
  }

  Widget buildDefaultWidget(BuildContext context) {
    return DefaultEntityContainer(
        state: _buildStatePart(context)
    );
  }

  Widget buildGlanceWidget(BuildContext context, bool showName, bool showState) {
    return GlanceEntityContainer(
      showName: showName,
      showState: showState,
    );
  }

  Widget _buildStatePart(BuildContext context) {
    return SimpleEntityState();
  }

  Widget _buildStatePartForPage(BuildContext context) {
    return _buildStatePart(context);
  }

  Widget _buildAdditionalControlsForPage(BuildContext context) {
    return Container(
      width: 0.0,
      height: 0.0,
    );
  }

  Widget buildEntityPageWidget(BuildContext context) {
    return EntityModel(
      entityWrapper: EntityWrapper(entity: this),
      child: EntityPageContainer(children: <Widget>[
        DefaultEntityContainer(state: _buildStatePartForPage(context)),
        LastUpdatedWidget(),
        Divider(),
        _buildAdditionalControlsForPage(context),
        Divider(),
        buildHistoryWidget(),
        EntityAttributesList()
      ]),
      handleTap: false,
    );
  }

  Widget buildHistoryWidget() {
    return EntityHistoryWidget(
      config: historyConfig,
    );
  }

  Widget buildBadgeWidget(BuildContext context) {
    return EntityModel(
      entityWrapper: EntityWrapper(entity: this),
      child: BadgeWidget(),
      handleTap: true,
    );
  }

  String getAttribute(String attributeName) {
    if (attributes != null) {
      return attributes["$attributeName"];
    }
    return null;
  }

  String _getLastUpdatedFormatted() {
    if (_lastUpdated == null) {
      return "-";
    } else {
      DateTime now = DateTime.now();
      Duration d = now.difference(_lastUpdated);
      String text;
      int v;
      if (d.inDays == 0) {
        if (d.inHours == 0) {
          if (d.inMinutes == 0) {
            text = "seconds ago";
            v = d.inSeconds;
          } else {
            text = "minutes ago";
            v = d.inMinutes;
          }
        } else {
          text = "hours ago";
          v = d.inHours;
        }
      } else {
        text = "days ago";
        v = d.inDays;
      }
      return "$v $text";
    }
  }
}
