import 'dart:developer' as developer;
import 'dart:io' as io;
import 'dart:math' as math;
import 'dart:typed_data' as typed_data;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart' as uuid;

import '../models/usuario.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../utils/constants.dart';

class MensajesScreen extends StatefulWidget {
  final String usuario;
  final bool isAdmin;

  const MensajesScreen({Key? key, this.usuario, this.isAdmin}) : super(key: key);

  @override
  _MensajesScreenState createState() => _MensajesScreenState();
}

class _MensajesScreenState extends State<MensajesScreen> {
  final _mensajeController = TextEditingController();
  bool _enviando = false;
  String? _destinatarioUsuario;
  String? _destinatarioTipo;
  bool _importante = false;

  @override
  void initState() {
    super.initState();
    _mensajeController.addListener(_onMensajeChanged);
  }

  @override
  void dispose() {
    _mensajeController.dispose();
    super.dispose();
  }

  void _onMensajeChanged() {
    if (_mensajeController.text.trim().isEmpty) return;
    setState(() => _enviando = true);
    final mensaje = _mensajeController.text.trim();
    final fecha = DateTime.now();
    final origenTipo = widget.isAdmin ? 'ADMIN' : _usuarios.firstWhere((u) => u['id'] == widget.usuario, orElse: () => {'tipo': ''})['tipo'] ?? '';
    if (!widget.isAdmin) {
      // Usuario normal: solo puede enviar mensajes a los ADMIN (tipo)
      await FirebaseFirestore.instance.collection('mensajes').add({
        'mensaje': mensaje,
        'fecha': fecha,
        'origen': widget.usuario,
        'origenTipo': origenTipo,
        'destino': 'ADMIN',
        'destinoTipo': 'ADMIN',
        'leido': false,
        'importante': false,
      });
    } else {
      if (_destinatarioUsuario != null) {
        // ADMIN: mensaje individual
        final destinoTipo = _usuarios.firstWhere((u) => u['id'] == _destinatarioUsuario, orElse: () => {'tipo': ''})['tipo'] ?? '';
        await FirebaseFirestore.instance.collection('mensajes').add({
          'mensaje': mensaje,
          'fecha': fecha,
          'origen': widget.usuario,
          'origenTipo': origenTipo,
          'destino': _destinatarioUsuario,
          'destinoTipo': destinoTipo,
          'leido': false,
          'importante': _importante ?? false,
        });
      } else if (_destinatarioTipo != null) {
        // ADMIN: mensaje grupal (por tipo de usuario, un solo mensaje)
        await FirebaseFirestore.instance.collection('mensajes').add({
          'mensaje': mensaje,
          'fecha': fecha,
          'origen': widget.usuario,
          'origenTipo': origenTipo,
          'destino': _destinatarioTipo,
          'destinoTipo': _destinatarioTipo,
          'leido': false,
          'importante': _importante ?? false,
        });
      } else {
        // ADMIN: mensaje a todos
        await FirebaseFirestore.instance.collection('mensajes').add({
          'mensaje': mensaje,
          'fecha': fecha,
          'origen': widget.usuario,
          'origenTipo': origenTipo,
          'destino': 'TODOS',
          'destinoTipo': 'TODOS',
          'leido': false,
          'importante': _importante ?? false,
        });
      }
    }
    setState(() {
      _enviando = false;
      _mensajeController.clear();
      _destinatarioUsuario = null;
      _destinatarioTipo = null;
    });
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mensajes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {},
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: _mensajes.length,
                itemBuilder: (context, index) {
                  return _buildMensajeItem(_mensajes[index]);
                },
              ),
            ),
            ElevatedButton(
              onPressed: _enviarMensaje,
              child: const Text('Enviar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMensajeItem(Mensaje mensaje) {
    return ListTile(
      title: Text(mensaje.mensaje),
      subtitle: Text(mensaje.fecha),
      trailing: Text(mensaje.leido ? 'Leído' : 'No leído'),
    );
  }

  Future<void> _enviarMensaje() async {
    if (_mensajeController.text.trim().isEmpty) return;
    setState(() => _enviando = true);
    final mensaje = _mensajeController.text.trim();
    final fecha = DateTime.now();
    final origenTipo = widget.isAdmin ? 'ADMIN' : _usuarios.firstWhere((u) => u['id'] == widget.usuario, orElse: () => {'tipo': ''})['tipo'] ?? '';
    if (!widget.isAdmin) {
      // Usuario normal: solo puede enviar mensajes a los ADMIN (tipo)
      await FirebaseFirestore.instance.collection('mensajes').add({
        'mensaje': mensaje,
        'fecha': fecha,
        'origen': widget.usuario,
        'origenTipo': origenTipo,
        'destino': 'ADMIN',
        'destinoTipo': 'ADMIN',
        'leido': false,
        'importante': false,
      });
    } else {
      if (_destinatarioUsuario != null) {
        // ADMIN: mensaje individual
        final destinoTipo = _usuarios.firstWhere((u) => u['id'] == _destinatarioUsuario, orElse: () => {'tipo': ''})['tipo'] ?? '';
        await FirebaseFirestore.instance.collection('mensajes').add({
          'mensaje': mensaje,
          'fecha': fecha,
          'origen': widget.usuario,
          'origenTipo': origenTipo,
          'destino': _destinatarioUsuario,
          'destinoTipo': destinoTipo,
          'leido': false,
          'importante': _importante ?? false,
        });
      } else if (_destinatarioTipo != null) {
        // ADMIN: mensaje grupal (por tipo de usuario, un solo mensaje)
        await FirebaseFirestore.instance.collection('mensajes').add({
          'mensaje': mensaje,
          'fecha': fecha,
          'origen': widget.usuario,
          'origenTipo': origenTipo,
          'destino': _destinatarioTipo,
          'destinoTipo': _destinatarioTipo,
          'leido': false,
          'importante': _importante ?? false,
        });
      } else {
        // ADMIN: mensaje a todos
        await FirebaseFirestore.instance.collection('mensajes').add({
          'mensaje': mensaje,
          'fecha': fecha,
          'origen': widget.usuario,
          'origenTipo': origenTipo,
          'destino': 'TODOS',
          'destinoTipo': 'TODOS',
          'leido': false,
          'importante': _importante ?? false,
        });
      }
    }
    setState(() {
      _enviando = false;
      _mensajeController.clear();
      _destinatarioUsuario = null;
      _destinatarioTipo = null;
    });
    Navigator.of(context).pop();
  }
}

