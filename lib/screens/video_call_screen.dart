import 'package:flutter/material.dart';
import 'dart:async'; // Ajout de l'import pour Timer
import 'package:permission_handler/permission_handler.dart';
// import 'package:flutter_webrtc/flutter_webrtc.dart'; // Suppression de cette dépendance
import '../services/call_service.dart';

class VideoCallScreen extends StatefulWidget {
  final String conversationId;
  final String userId;
  final String recipientName;
  final String recipientAvatar;
  final bool isGroup;

  const VideoCallScreen({
    Key? key,
    required this.conversationId,
    required this.userId,
    required this.recipientName,
    required this.recipientAvatar,
    this.isGroup = false,
  }) : super(key: key);

  @override
  _VideoCallScreenState createState() => _VideoCallScreenState();

  static Future<void> open(BuildContext context, {
    required String selfUserId,
    required String otherUserId,
    required String callId,
    required bool isCaller,
    required bool isVideo,
  }) async {
    await Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => VideoCallScreen(
          conversationId: callId,
          userId: selfUserId,
          recipientName: otherUserId,
          recipientAvatar: '',
          isGroup: !isCaller,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final fade = CurvedAnimation(parent: animation, curve: Curves.easeInOut);
          final scale = Tween<double>(begin: 0.95, end: 1.0).animate(fade);
          return FadeTransition(
            opacity: fade,
            child: ScaleTransition(
              scale: scale,
              child: child,
            ),
          );
        },
        transitionDuration: Duration(milliseconds: 350),
      ),
    );
  }
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  // Suppression des renderers WebRTC
  // final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  // final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  // MediaStream? _localStream;
  // RTCPeerConnection? _peerConnection;
  
  bool _isMuted = false;
  bool _isCameraOff = false;
  bool _isSpeakerOn = true;
  bool _isConnecting = true;
  Duration _callDuration = Duration.zero;
  late Timer _callTimer;
  
  @override
  void initState() {
    super.initState();
    _initCall();
  }
  
  @override
  void dispose() {
    // Nettoyage des ressources
    _callTimer.cancel();
    super.dispose();
  }
  
  Future<void> _initCall() async {
    try {
      // Simulation d'initialisation d'appel
      await Future.delayed(Duration(seconds: 2));
      
      if (mounted) {
        setState(() {
          _isConnecting = false;
        });
        
        // Démarrer le minuteur d'appel
        _callTimer = Timer.periodic(Duration(seconds: 1), (timer) {
          if (mounted) {
            setState(() {
              _callDuration = Duration(seconds: timer.tick);
            });
          }
        });
      }
    } catch (e) {
      print('Erreur lors de l\'initialisation de l\'appel simulé: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de l\'initialisation de l\'appel')),
        );
        Navigator.pop(context);
      }
    }
  }
  
  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      print('Microphone ${_isMuted ? 'coupé' : 'activé'}');
    });
  }
  
  void _toggleCamera() {
    setState(() {
      _isCameraOff = !_isCameraOff;
      print('Caméra ${_isCameraOff ? 'désactivée' : 'activée'}');
    });
  }
  
  void _toggleSpeaker() {
    setState(() {
      _isSpeakerOn = !_isSpeakerOn;
      print('Haut-parleur ${_isSpeakerOn ? 'activé' : 'désactivé'}');
    });
  }
  
  void _endCall() {
    Navigator.pop(context);
  }
  
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Vue principale (flux distant simulé)
          Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.grey[800],
            child: _isConnecting ? 
              Center(child: CircularProgressIndicator(color: Colors.white)) : 
              Center(
                child: Icon(
                  widget.isGroup ? Icons.groups : Icons.person,
                  size: 120,
                  color: Colors.white54,
                ),
              ),
          ),
          
          // Afficher un état de connexion si nécessaire
          if (_isConnecting)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text(
                    'Connexion à ${widget.recipientName}...',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ],
              ),
            ),
          
          // Vidéo locale en incrustation (PiP)
          Positioned(
            right: 16,
            top: 60,
            child: Container(
              width: 100,
              height: 150,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white, width: 2),
                color: _isCameraOff ? Colors.grey[900] : Colors.grey[600],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: _isCameraOff 
                  ? Center(child: Icon(Icons.videocam_off, color: Colors.white)) 
                  : Center(child: Icon(Icons.person, color: Colors.white70, size: 50)),
              ),
            ),
          ),
          
          // Informations sur l'appel en haut
          Positioned(
            top: 40,
            left: 16,
            right: 16,
            child: Column(
              children: [
                Text(
                  widget.recipientName,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  !_isConnecting ? _formatDuration(_callDuration) : 'Appel en cours...',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          
          // Contrôles en bas
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildControlButton(
                  icon: _isMuted ? Icons.mic_off : Icons.mic,
                  label: _isMuted ? 'Activer' : 'Muet',
                  color: _isMuted ? Colors.red : Colors.white,
                  onPressed: _toggleMute,
                ),
                _buildControlButton(
                  icon: _isCameraOff ? Icons.videocam_off : Icons.videocam,
                  label: _isCameraOff ? 'Activer' : 'Désactiver',
                  color: _isCameraOff ? Colors.red : Colors.white,
                  onPressed: _toggleCamera,
                ),
                _buildControlButton(
                  icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_off,
                  label: _isSpeakerOn ? 'HP Off' : 'HP On',
                  color: Colors.white,
                  onPressed: _toggleSpeaker,
                ),
                _buildControlButton(
                  icon: Icons.call_end,
                  label: 'Raccrocher',
                  color: Colors.red,
                  backgroundColor: Colors.red.shade800,
                  onPressed: _endCall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required Color color,
    Color? backgroundColor,
    required VoidCallback onPressed,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: backgroundColor ?? Colors.black.withOpacity(0.5),
          ),
          child: IconButton(
            icon: Icon(icon),
            color: color,
            iconSize: 30,
            onPressed: onPressed,
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
} 