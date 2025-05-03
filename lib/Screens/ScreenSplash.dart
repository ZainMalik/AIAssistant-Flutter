import 'package:animated_splash_screen/animated_splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:ai_assistant/Screens/ScreenHome.dart';
import 'package:lottie/lottie.dart';

class ScreenSplash extends StatelessWidget {
  const ScreenSplash({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedSplashScreen(
      splash: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Lottie.network(
          //   "https://lottie.host/08917e40-ce1c-472c-aab1-8cb643f45caf/w8htzgNZoc.json",
          //   fit: BoxFit.contain,
          //   width: 300,
          //   height: 300,
          // ),
          Lottie.asset(
            'assets/lottie_chat.json',
            width: 200,
            height: 200,
            repeat: true,
            animate: true,
          ),
        ],
      ),
      nextScreen: ScreenHome(),
      duration: 4000,
      splashIconSize: 400,
      backgroundColor: Colors.white  ,
      centered: true,
    );
  }
}
