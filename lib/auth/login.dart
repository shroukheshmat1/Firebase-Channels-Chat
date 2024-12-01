import 'package:flutter/material.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Login", style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),),
                const SizedBox(height: 20),
                const Text("Login to Continue Using this App", style: TextStyle(color: Color.fromARGB(255, 53, 69, 93)),),
                const SizedBox(height: 20),

                const Text("Email", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),),
                const SizedBox(height: 10,),
                TextFormField(
                  decoration: InputDecoration(
                    hintText: "Enter Your Email",
                    hintStyle: const TextStyle(fontSize: 14, color: Colors.grey),
                    contentPadding: const EdgeInsets.symmetric(vertical: 2, horizontal: 20),
                    filled: true,
                    fillColor: const Color.fromARGB(255, 53, 69, 93),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: const BorderSide(color: Color.fromARGB(255, 53, 69, 93))
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: const BorderSide(color: Color.fromARGB(255, 53, 69, 93))
                    )
                  ),
                ),

                const SizedBox(height: 20,),

                const Text("Password", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 10,),
                TextFormField(
                  decoration: InputDecoration(
                    hintText: "Enter Your Password",
                    hintStyle: const TextStyle(fontSize: 14, color: Colors.grey),
                    contentPadding: const EdgeInsets.symmetric(vertical: 2, horizontal: 20),
                    filled: true,
                    fillColor: const Color.fromARGB(255, 53, 69, 93),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: const BorderSide(color: Color.fromARGB(255, 53, 69, 93))
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: const BorderSide(color: Color.fromARGB(255, 53, 69, 93))
                    )
                  ),
                ),

                const SizedBox(height: 25,),
              ],
            ),
            MaterialButton(
              color: const Color(0xFF1F2937),
              textColor: Colors.white,
              onPressed: (){},
              child: const Text(
                "Login",
                style: TextStyle(

                ),
                ),
            )
          ],
        ),
      ),
    );
  }
}
