import 'dart:io';
import 'package:app_via_assignment/screens/userdata.dart';
import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_storage/firebase_storage.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key, this.cameras});
  final List<CameraDescription>? cameras;

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraController _cameraController;
  bool _isRearCameraSelected = true;
  bool isClicked = false;
  XFile? picture;
  String? subLocality;
  String? city;
  double? lat;
  double? long;
  Position? _position;
  bool isUploading = false;

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    initCamera(widget.cameras![1]);
  }

  Future takePicture() async {
    if (!_cameraController.value.isInitialized) {
      return null;
    }
    if (_cameraController.value.isTakingPicture) {
      return null;
    }
    try {
      await _cameraController.setFlashMode(FlashMode.off);
      XFile image = await _cameraController.takePicture();
      _position = await determinePosition();
      getAddress(_position!.latitude, _position!.longitude);
      setState(() {
        picture = image;
        isClicked = true;
        print(_position?.latitude);
      });
    } on CameraException catch (e) {
      debugPrint('Error occured while taking picture: $e');
      return null;
    }
  }

  Future initCamera(CameraDescription cameraDescription) async {
    _cameraController =
        CameraController(cameraDescription, ResolutionPreset.high);
    try {
      await _cameraController.initialize().then((_) {
        if (!mounted) return;
        setState(() {});
      });
    } on CameraException catch (e) {
      debugPrint("camera error $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: SafeArea(
      child: Stack(children: [
        isClicked
            ? Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Image.file(File(picture!.path), fit: BoxFit.cover),
                  const SizedBox(height: 24),
                  Text(picture!.name)
                ]),
              )
            : (_cameraController.value.isInitialized)
                ? CameraPreview(_cameraController)
                : Container(
                    color: Colors.black,
                    child: const Center(child: CircularProgressIndicator())),
        Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: MediaQuery.of(context).size.height * 0.20,
              decoration: const BoxDecoration(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  color: Colors.black),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                isClicked
                    ? Expanded(
                        child: IconButton(
                        onPressed: () {
                          isClicked = false;
                          setState(() {});
                        },
                        iconSize: 50,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(Icons.close_outlined,
                            color: Colors.white),
                      ))
                    : Expanded(
                        child: IconButton(
                        padding: EdgeInsets.zero,
                        iconSize: 30,
                        icon: Icon(
                            _isRearCameraSelected
                                ? CupertinoIcons.switch_camera
                                : CupertinoIcons.switch_camera_solid,
                            color: Colors.white),
                        onPressed: () {
                          setState(() =>
                              _isRearCameraSelected = !_isRearCameraSelected);
                          initCamera(
                              widget.cameras![_isRearCameraSelected ? 1 : 0]);
                        },
                      )),
                Expanded(
                    child: IconButton(
                  onPressed: takePicture,
                  iconSize: 50,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.circle, color: Colors.white),
                )),
                isClicked
                    ? Expanded(
                        child: IconButton(
                        onPressed: () {
                          storeData(city!, subLocality!,
                              DateTime.now().toString(), picture!);
                          setState(() {});
                        },
                        iconSize: 50,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(Icons.check, color: Colors.white),
                      ))
                    : const Spacer(),
              ]),
            )),
      ]),
    ));
  }

  Future<Position> determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }
    return await Geolocator.getCurrentPosition();
  }

  Future<void> getAddress(double lat, double long) async {
    List<Placemark> placemarks = await placemarkFromCoordinates(lat, long);
    subLocality = placemarks[0].subLocality;
    city = placemarks[0].locality;
    setState(() {});
  }

  Future<String> generateLink(XFile picture) async {
    File data = File(picture.path);
    FirebaseStorage storage = FirebaseStorage.instance;
    TaskSnapshot taskSnapshot =
        await storage.ref(FirebaseAuth.instance.currentUser?.uid).putFile(data);
    return await taskSnapshot.ref.getDownloadURL();
  }

  storeData(String city, String sublocality, String time, XFile picture) async {
    showCupertinoDialog(
      context: context,
      builder: (context) => const CupertinoAlertDialog(
        content: SizedBox(
          height: 50,
          width: 50,
          child: Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        ),
      ),
    );
    String link = await generateLink(picture);
    FirebaseFirestore db = FirebaseFirestore.instance;
    db
        .collection("UserData")
        .doc(FirebaseAuth.instance.currentUser?.uid)
        .set({
          "ImageUrl": link,
          "Latitude": city,
          "Longitude": sublocality,
          "Time": time
        })
        .whenComplete(() => Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const UserData()),
            (Route<dynamic> route) => false))
        .catchError((e) {});
  }
}
