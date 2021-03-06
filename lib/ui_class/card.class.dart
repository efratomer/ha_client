part of '../main.dart';

class HACard {
  List<EntityWrapper> entities = [];
  EntityWrapper linkedEntity;
  String name;
  String id;
  String type;
  bool showName;
  bool showState;
  int columnsCount;

  HACard({
    this.name,
    this.id,
    this.linkedEntity,
    this.columnsCount: 4,
    this.showName: true,
    this.showState: true,
    @required this.type
  });

  Widget build(BuildContext context) {
      switch (type) {

        case "entities": {
          return EntitiesCardWidget(
            card: this,
          );
        }

        case "glance": {
          return GlanceCardWidget(
            card: this,
          );
        }

        case "media-control": {
          return MediaControlCardWidget(
            card: this,
          );
        }

        case "weather-forecast":
        case "thermostat":
        case "sensor":
        case "plant-status":
        case "picture-entity":
        case "picture-elements":
        case "picture":
        case "map":
        case "iframe":
        case "gauge":
        case "entity-button":
        case "conditional":
        case "alarm-panel": {
          return UnsupportedCardWidget(
            card: this,
          );
        }

        default: {
          if ((linkedEntity == null) && (entities.isNotEmpty)) {
            return EntitiesCardWidget(
              card: this,
            );
          } else {
            return UnsupportedCardWidget(
              card: this,
            );
          }
        }

      }
  }

}