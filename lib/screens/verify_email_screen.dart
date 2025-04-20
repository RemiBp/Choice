import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../utils/constants.dart' as constants;
import 'package:lottie/lottie.dart';

class VerifyEmailScreen extends StatefulWidget {
  final String? token; // Token fourni via les paramètres de route
  final String? email; // Email à vérifier (optionnel)

  const VerifyEmailScreen({Key? key, this.token, this.email}) : super(key: key);

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool _isLoading = false;
  bool _isVerified = false;
  bool _hasError = false;
  String _message = '';
  Timer? _resendTimer;
  int _resendCountdown = 0;

  @override
  void initState() {
    super.initState();
    _verifyEmail();
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    super.dispose();
  }

  Future<void> _verifyEmail() async {
    // Si aucun token n'est fourni, on est en mode d'affichage seulement
    if (widget.token == null) {
      setState(() {
        _isLoading = false;
        _message = 'email.check_inbox'.tr();
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _message = 'email.verifying'.tr();
    });

    try {
      final response = await http.get(
        Uri.parse('${constants.getBaseUrl()}/api/verify-email/${widget.token}'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          // Authentification automatique avec le token retourné
          await _loginWithToken(data['token'], data['user']);

          setState(() {
            _isLoading = false;
            _isVerified = true;
            _message = 'email.verified_success'.tr();
          });

          // Naviguer vers l'écran principal après un délai
          Future.delayed(const Duration(seconds: 3), () {
            Navigator.of(context).pushReplacementNamed('/');
          });
        } else {
          setState(() {
            _isLoading = false;
            _hasError = true;
            _message = data['message'] ?? 'email.verification_failed'.tr();
          });
        }
      } else {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _message = 'email.verification_failed'.tr();
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _message = 'email.server_error'.tr();
      });
    }
  }

  Future<void> _loginWithToken(String token, Map<String, dynamic> userData) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    await authService.loginWithToken(token, userData);
  }

  Future<void> _resendVerificationEmail() async {
    setState(() {
      _isLoading = true;
      _message = 'email.sending'.tr();
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      
      if (!authService.isAuthenticated) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _message = 'email.need_login'.tr();
        });
        return;
      }
      
      final response = await http.post(
        Uri.parse('${constants.getBaseUrl()}/api/email/resend-verification'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${authService.token}',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        setState(() {
          _isLoading = false;
          _message = data['message'] ?? 'email.resent_success'.tr();
        });
        
        // Démarrer le compte à rebours
        _startResendCountdown();
      } else if (response.statusCode == 429) {
        // Trop de tentatives
        final data = json.decode(response.body);
        
        setState(() {
          _isLoading = false;
          _message = data['message'] ?? 'email.too_many_attempts'.tr();
        });
      } else {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _message = 'email.resend_failed'.tr();
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _message = 'email.server_error'.tr();
      });
    }
  }

  void _startResendCountdown() {
    setState(() {
      _resendCountdown = 60; // 60 secondes avant de pouvoir renvoyer un email
    });

    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_resendCountdown > 0) {
          _resendCountdown--;
        } else {
          _resendTimer?.cancel();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('email.verification_title'.tr()),
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Animation en fonction de l'état
              _isLoading
                  ? Lottie.network(
                      'https://assets9.lottiefiles.com/datafiles/bEYvzB8QfV3EM9a/data.json',
                      width: 200,
                      height: 200,
                    )
                  : _isVerified
                      ? Lottie.network(
                          'https://assets3.lottiefiles.com/packages/lf20_sx3muasw.json',
                          width: 200,
                          height: 200,
                          repeat: false,
                        )
                      : _hasError
                          ? Lottie.network(
                              'https://assets10.lottiefiles.com/packages/lf20_qpwbiyxf.json',
                              width: 200,
                              height: 200,
                            )
                          : Lottie.network(
                              'https://assets10.lottiefiles.com/private_files/lf30_T6E3bh.json',
                              width: 200,
                              height: 200,
                            ),
              const SizedBox(height: 32),
              
              // Afficher un titre basé sur l'état
              Text(
                _isVerified
                    ? 'email.verified_title'.tr()
                    : _hasError
                        ? 'email.error_title'.tr()
                        : 'email.verification_pending_title'.tr(),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              
              // Message
              Text(
                _message,
                style: TextStyle(
                  fontSize: 16,
                  color: _hasError ? Colors.red : Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              
              // Email
              if (widget.email != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.email, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text(
                        widget.email!,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 32),
              
              // Bouton pour renvoyer l'email de vérification
              if (!_isVerified)
                ElevatedButton.icon(
                  onPressed: _resendCountdown > 0 || _isLoading
                      ? null
                      : _resendVerificationEmail,
                  icon: const Icon(Icons.refresh),
                  label: Text(_resendCountdown > 0
                      ? 'email.resend_countdown'.tr(args: {'seconds': _resendCountdown.toString()})
                      : 'email.resend'.tr()),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                ),
              
              const SizedBox(height: 16),
              
              // Lien pour retourner à l'accueil
              TextButton(
                onPressed: () {
                  Navigator.of(context).pushReplacementNamed('/');
                },
                child: Text('common.back_to_home'.tr()),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 