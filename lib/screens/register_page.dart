import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:task2_chat_rooms/screens/login_page.dart';
import 'package:task2_chat_rooms/services/notification_service.dart';
import 'home_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<StatefulWidget> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseAnalytics analytics = FirebaseAnalytics.instance;

  String? _verificationId;

  Future<void> _registerWithEmail() async {
    try {
      final UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim());
      final user = userCredential.user;

      if (user != null) {
        await _addUser(user);

        await analytics.logEvent(
          name: 'first_time_login',
          parameters: {'user_id': user.uid, 'method': 'email'},
        );
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const ChatOrbitHomePage()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Registration Failed: $e')),
      );
    }
  }

  Future<void> _registerWithPhone() async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: _phoneController.text.trim(),
        verificationCompleted: (PhoneAuthCredential credential) async {
          final UserCredential userCredential =
            await _auth.signInWithCredential(credential);
          final user = userCredential.user;
          if (user != null) {
            await _addUser(user);
            await analytics.logEvent(
              name: 'first_time_login',
              parameters: {'user_id': user.uid, 'method': 'phone'},
            );
          }
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const ChatOrbitHomePage()),
          );
        },
        verificationFailed: (FirebaseAuthException e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Phone Verification Failed: ${e.message}')),
          );
        },
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('OTP sent to your phone.')),
          );
          // Show dialog or UI for entering OTP
          _showOtpDialog();
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Registration Failed: $e')));
    }
  }

  void _showOtpDialog() {
    showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Enter OTP'),
            content: TextField(
              controller: _otpController,
              decoration: const InputDecoration(hintText: 'Enter OTP'),
              keyboardType: TextInputType.number,
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  final otp = _otpController.text.trim();
                  if (_verificationId != null && otp.isNotEmpty) {
                    PhoneAuthCredential credential = PhoneAuthProvider.credential(
                      verificationId: _verificationId!,
                      smsCode: otp,
                    );
                    try {
                      final UserCredential userCredential =
                        await _auth.signInWithCredential(credential);
                      final user = userCredential.user;
                      if (user != null) {
                        await _addUser(user);
                        await analytics.logEvent(
                          name: 'first_time_login',
                          parameters: {'user_id': user.uid, 'method': 'phone'},
                        );
                      }
                      Navigator.pop(context);
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const ChatOrbitHomePage()),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('OTP Verification Failed: $e')),
                      );
                    }
                     // Close the dialog
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a valid OTP')),
                    );
                  }
                },
                child: const Text('Verify'),
              ),
            ],
          );
        },
    );
  }

  Future<void> _registerWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

      final GoogleSignInAuthentication? googleAuth =
      await googleUser?.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth?.accessToken,
        idToken: googleAuth?.idToken,
      );

      final UserCredential userCredential =
      await _auth.signInWithCredential(credential);
      final user = userCredential.user;

      if (user != null) {
        await _addUser(user);
        await analytics.logEvent(
          name: 'first_time_login',
          parameters: {'user_id': user.uid, 'method': 'google'},
        );
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const ChatOrbitHomePage()),
      );

    } on Exception catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google Registration Failed: $e')),
      );
    }
  }

  Future<void> _addUser(User user) async {
    final userRef =
    FirebaseFirestore.instance.collection('users').doc(user.uid);
    final docSnapshot = await userRef.get();

    if (!docSnapshot.exists) {
      if (user.email != null){
        await userRef.set({'email': user.email, 'subscriptions': []});
      }
      else{
        await userRef.set({'phoneNumber': user.phoneNumber, 'subscriptions': []});
      }
      await NotificationService.instance.showNotificationWithDetails('Welcome', 'Welcome to Our Application');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        padding: const EdgeInsets.all(20.0),
        child: ListView(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Register", style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),),
                const SizedBox(height: 10),
                const Text("Create an Account to Continue Using this App", style: TextStyle(color: Color.fromARGB(255, 53, 69, 93)),),
                const SizedBox(height: 20),

                const Text("Email", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),),
                const SizedBox(height: 10,),
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(
                      hintText: "Enter Your Email",
                      hintStyle: const TextStyle(fontSize: 14, color:Color.fromARGB(255, 53, 69, 93)),
                      contentPadding: const EdgeInsets.symmetric(vertical: 2, horizontal: 20),
                      filled: true,
                      fillColor: Colors.grey[300],
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: const BorderSide(color: Colors.grey)
                      ),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: const BorderSide(color: Colors.grey)
                      )
                  ),
                ),

                const SizedBox(height: 20,),

                const Text("Password", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 10,),
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                      hintText: "Enter Your Password",
                      hintStyle: const TextStyle(fontSize: 14, color: Color.fromARGB(255, 53, 69, 93)),
                      contentPadding: const EdgeInsets.symmetric(vertical: 2, horizontal: 20),
                      filled: true,
                      fillColor: Colors.grey[300],
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: const BorderSide(color: Colors.grey)
                      ),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: const BorderSide(color: Colors.grey)
                      )
                  ),
                ),

                const SizedBox(height: 25,),
              ],
            ),
            MaterialButton(
              height: 50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              color: const Color(0xFF1F2937),
              textColor: Colors.white,
              onPressed: _registerWithEmail,
              child: const Text(
                "Register",
              ),
            ),
            const SizedBox(height: 20,),
            MaterialButton(
              height: 50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              color: const Color(0xFF1F2937),
              textColor: Colors.white,
              onPressed: _registerWithGoogle,
              child:
              const Text(
                "Register Using Google",
              ),
            ),
            const SizedBox(height: 20,),

            const Text("Phone Number", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 10,),
            TextFormField(
              controller: _phoneController,
              decoration: InputDecoration(
                  hintText: "Enter Your Phone (+20XXXXXXXXXX)",
                  hintStyle: const TextStyle(fontSize: 14, color: Color.fromARGB(255, 53, 69, 93)),
                  contentPadding: const EdgeInsets.symmetric(vertical: 2, horizontal: 20),
                  filled: true,
                  fillColor: Colors.grey[300],
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: const BorderSide(color: Colors.grey)
                  ),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: const BorderSide(color: Colors.grey)
                  )
              ),
            ),
            const SizedBox(height: 10,),
            MaterialButton(
              height: 50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              color: const Color(0xFF1F2937),
              textColor: Colors.white,
              onPressed: _registerWithPhone,
              child: const Text(
                "Register With Phone",
              ),
            ),
            const SizedBox(height: 20,),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Already Have An Account? "),
                InkWell(
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const LoginPage()),
                    );
                  },
                  child: const Text(
                    "Login",
                    style: TextStyle(color: Color(0xFF1F2937)),
                  ),
                )
              ],
            )


          ],

        ),
      ),
    );
  }
}


