import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:task2_chat_rooms/screens/register_page.dart';
import 'home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<StatefulWidget> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // ---------------------------------------------
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  String? _verificationId;
  // ---------------------------------------------


  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> _loginWithEmail() async {
    try {
      await _auth.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim());

      // final user = FirebaseAuth.instance.currentUser;
      // if (user != null) {
      //   await _addUser(user);
      // }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const ChatOrbitHomePage()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Login Failed: $e')));
    }
  }

  // Future<void> _addUser(User user) async {
  //   final userRef =
  //       FirebaseFirestore.instance.collection('users').doc(user.uid);
  //   final docSnapshot = await userRef.get();
  //
  //   if (!docSnapshot.exists) {
  //     await userRef.set({'email': user.email, 'subscriptions': []});
  //   }
  // }

  Future<void> _loginWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      final GoogleSignInAuthentication? googleAuth =
      await googleUser?.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth?.accessToken,
        idToken: googleAuth?.idToken,
      );

      await _auth.signInWithCredential(credential);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const ChatOrbitHomePage()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google Login Failed: $e')),
      );
    }
  }

  Future<void> _loginWithPhone() async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: _phoneController.text.trim(),
        verificationCompleted: (PhoneAuthCredential credential) async {
          await _auth.signInWithCredential(credential);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const ChatOrbitHomePage()),
          );
        },
        verificationFailed: (FirebaseAuthException e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Phone Login Failed: ${e.message}')),
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
          setState(() {
            _verificationId = verificationId;
          });
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Phone Login Failed: $e')),
      );
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
                    await _auth.signInWithCredential(credential);
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
                const Text("Login", style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),),
                const SizedBox(height: 10),
                const Text("Login to Continue Using this App", style: TextStyle(color: Color.fromARGB(255, 53, 69, 93)),),
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
              onPressed: _loginWithEmail,
              child: const Text(
                "Login",
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
              onPressed: _loginWithGoogle,
              child: const Text(
                "Login With Google",
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
              onPressed: _loginWithPhone,
              child: const Text(
                "Login With Phone",
              ),
            ),
            const SizedBox(height: 20,),
            Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Don't Have An Account? "),
                  InkWell(
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => const RegisterPage()),
                      );
                    },
                    child: const Text(
                        "Register",
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
