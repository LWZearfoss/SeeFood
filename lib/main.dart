import 'package:flutter/material.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_webservice/places.dart';
import 'package:http/http.dart';
import 'package:image_picker_modern/image_picker_modern.dart';
import 'package:path/path.dart';

import 'api_key.dart';

class Place {
  double latitude;
  double longitude;
  String id;
  String name;
  String address;
  Image photo;
  Place(this.latitude, this.longitude, this.id, this.name, this.address,
      this.photo);
}

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: FirstPage(),
    );
  }
}

class FirstPage extends StatefulWidget {
  @override
  _FirstPageState createState() => _FirstPageState();
}

class _FirstPageState extends State<FirstPage> {
  var location;
  File image;
  var data;

  Future getImage() async {
    var image = await ImagePicker.pickImage(source: ImageSource.gallery);
    setState(() {
      this.image = image;
      if (image != null) {
        data = (var location, var image) async {
          Response vision = await post(
              'https://vision.googleapis.com/v1/images:annotate?key=' +
                  googleApiKey,
              headers: {'Content-type': 'application/json'},
              body: jsonEncode({
                'requests': [
                  {
                    'image': {'content': base64Encode(image.readAsBytesSync())},
                    'features': [
                      {'type': 'WEB_DETECTION', 'maxResults': 1}
                    ]
                  }
                ]
              }));
          return jsonDecode(vision.body)['responses'][0]['webDetection']
              ['webEntities'][0]['description'];
        }(location, image)
            .then((food) {
          return (var location, String food) async {
            var google = GoogleMapsPlaces(apiKey: googleApiKey);
            var places = await google.searchByText(food + ' food',
                location: Location(location['latitude'], location['longitude']),
                type: 'restaurant');
            return [
              location,
              food,
              places.results.map((res) {
                return Place(
                    res.geometry.location.lat,
                    res.geometry.location.lng,
                    res.placeId,
                    res.name,
                    res.formattedAddress,
                    Image.network(
                        google.buildPhotoUrl(
                            photoReference: res.photos[0].photoReference,
                            maxHeight: 300),
                        fit: BoxFit.cover));
              }).toList()
            ];
          }(location, food);
        });
      }
    });
  }

  @override
  void initState() {
    super.initState();
    () async {
      Response response = await get('https://ipapi.co/json');
      return json.decode(response.body);
    }()
        .then((location) {
      this.location = location;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('SeeFood'),
        backgroundColor: Colors.cyan[300],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            SizedBox(
                height: 150.0,
                width: 300.0,
                child: OutlineButton(
                    onPressed: getImage,
                    splashColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5.0)),
                    child: this.image == null
                        ? Text('No image selected')
                        : Text(basename(this.image.path),
                            textAlign: TextAlign.center))),
            SizedBox(height: 5.0),
            SizedBox(
                height: 20.0,
                width: 280.0,
                child: RaisedButton(
                  color: Colors.cyan,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(2.5)),
                  textColor: Colors.white,
                  splashColor: Colors.transparent,
                  disabledTextColor: Colors.white,
                  disabledColor: Colors.cyan[100],
                  onPressed: this.location == null || this.image == null
                      ? null
                      : () {
                          Navigator.push(
                              context,
                              new MaterialPageRoute(
                                  builder: (context) =>
                                      new SecondPage(data: this.data)));
                        },
                  child: Text(
                    'Upload',
                    style: TextStyle(fontSize: 14.0),
                  ),
                ))
          ],
        ),
      ),
    );
  }
}

class SecondPage extends StatefulWidget {
  final data;
  const SecondPage({Key key, @required this.data}) : super(key: key);

  @override
  _SecondPageState createState() => _SecondPageState(this.data);
}

class _SecondPageState extends State<SecondPage> {
  _SecondPageState(this.data);
  final data;
  final Completer<GoogleMapController> _mapController = Completer();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: data,
        builder: (BuildContext context, AsyncSnapshot<dynamic> snapshot) {
          if (!snapshot.hasData) {
            return Scaffold(
                appBar: AppBar(
                    backgroundColor: Colors.cyan[300],
                    title: const Text('Loading...')),
                body: Center());
          }
          return Scaffold(
            appBar: AppBar(
              backgroundColor: Colors.cyan[300],
              title: Text(snapshot.data[1]),
            ),
            body: Stack(
              children: <Widget>[
                RestaurantMap(
                  places: snapshot.data[2],
                  initialPosition: LatLng(snapshot.data[0]['latitude'],
                      snapshot.data[0]['longitude']),
                  mapController: _mapController,
                ),
                RestaurantCarousel(
                  places: snapshot.data[2],
                  mapController: _mapController,
                ),
              ],
            ),
          );
        });
  }
}

class RestaurantCarousel extends StatelessWidget {
  const RestaurantCarousel({
    Key key,
    @required this.places,
    @required this.mapController,
  }) : super(key: key);

  final places;
  final Completer<GoogleMapController> mapController;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: SizedBox(
          height: 90,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: places.length,
            itemBuilder: (builder, index) {
              return SizedBox(
                width: 340,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Card(
                    child: Center(
                      child: RestaurantListTile(
                        place: places[index],
                        mapController: mapController,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class RestaurantListTile extends StatefulWidget {
  const RestaurantListTile({
    Key key,
    @required this.place,
    @required this.mapController,
  }) : super(key: key);

  final place;
  final Completer<GoogleMapController> mapController;

  @override
  State<StatefulWidget> createState() {
    return _RestaurantListTileState();
  }
}

class _RestaurantListTileState extends State<RestaurantListTile> {
  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(widget.place.name),
      subtitle: Text(widget.place.address),
      leading: Container(
        child: ClipRRect(
          child: widget.place.photo,
          borderRadius: const BorderRadius.all(Radius.circular(2)),
        ),
        width: 100,
        height: 60,
      ),
      onTap: () async {
        final controller = await widget.mapController.future;
        await controller.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(
                widget.place.latitude,
                widget.place.longitude,
              ),
              zoom: 18,
            ),
          ),
        );
      },
    );
  }
}

class RestaurantMap extends StatelessWidget {
  const RestaurantMap({
    Key key,
    @required this.places,
    @required this.initialPosition,
    @required this.mapController,
  }) : super(key: key);

  final List<Place> places;
  final LatLng initialPosition;
  final Completer<GoogleMapController> mapController;

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: initialPosition,
        zoom: 12,
      ),
      markers: Set<Marker>.from(places.map((place) => Marker(
          markerId: MarkerId(place.id),
          icon: BitmapDescriptor.defaultMarkerWithHue(350.0),
          position: LatLng(place.latitude, place.longitude),
          infoWindow: InfoWindow(title: place.name, snippet: place.address)))),
      onMapCreated: (mapController) {
        this.mapController.complete(mapController);
      },
    );
  }
}
