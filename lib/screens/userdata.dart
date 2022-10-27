import 'package:app_via_assignment/screens/signup.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_sign_in/google_sign_in.dart';

class UserData extends StatefulWidget {
  const UserData({super.key});

  @override
  State<UserData> createState() => _UserDataState();
}

class _UserDataState extends State<UserData> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Hello")),
      body: SafeArea(
        child: Center(
          child: StreamBuilder(
            stream: FirebaseFirestore.instance
                .collection("UserData")
                .doc((FirebaseAuth.instance.currentUser?.uid)!)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                      height: MediaQuery.of(context).size.height / 3,
                      width: MediaQuery.of(context).size.width / 2,
                      child: Image.network(snapshot.data?.data()?["ImageUrl"])),
                  const SizedBox(
                    height: 10,
                  ),
                  Text(
                      "Place : ${snapshot.data?.data()?["Latitude"]} , ${snapshot.data?.data()?["Longitude"]}"),
                  const SizedBox(
                    height: 10,
                  ),
                  Text(
                      "Created At : ${(snapshot.data?.data()?["Time"]).toString().substring(0, 19)}"),
                  ElevatedButton(
                      onPressed: () {
                        GoogleSignIn().signOut();
                        FirebaseAuth.instance.signOut();
                        Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                                builder: (context) => const SignupPage()),
                            (Route<dynamic> route) => false);
                      },
                      child: const Text("Logout"))
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
