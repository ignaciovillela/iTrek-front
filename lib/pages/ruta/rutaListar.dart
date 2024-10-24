import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:itrek/db.dart'; // Importar el helper de base de datos
import 'package:itrek/img.dart';
import 'package:itrek/pages/ruta/rutaRecorrer.dart';
import 'package:itrek/request.dart';

class ListadoRutasScreen extends StatefulWidget {
  const ListadoRutasScreen({super.key});

  @override
  _ListadoRutasScreenState createState() => _ListadoRutasScreenState();
}

class _ListadoRutasScreenState extends State<ListadoRutasScreen> {
  List<dynamic>? rutasGuardadas;

  @override
  void initState() {
    super.initState();
    _fetchRutas();
  }

  Future<void> _fetchRutas() async {
    await makeRequest(
      method: GET,
      url: 'api/routes/',
      onOk: (response) {
        setState(() {
          rutasGuardadas = jsonDecode(response.body);
        });
      },
      onError: (response) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al cargar las rutas')),
        );
      },
      onDefault: (response) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error inesperado: ${response.statusCode}')),
        );
      },
      onConnectionError: (errorMessage) {
        print(errorMessage);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      },
    );
  }

  Future<void> _deleteRuta(int id) async {
    await makeRequest(
      method: DELETE,
      url: 'api/routes/$id/',
      onOk: (response) {
        setState(() {
          rutasGuardadas!.removeWhere((ruta) => ruta['id'] == id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ruta eliminada con éxito')),
        );
      },
      onError: (response) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al eliminar la ruta')),
        );
      },
      onConnectionError: (errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context, int id) async {
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirmar eliminación'),
          content: const Text('¿Estás seguro de que deseas eliminar esta ruta? Esta acción no se puede deshacer.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    if (shouldDelete == true) {
      _deleteRuta(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget bodyContent;

    if (rutasGuardadas == null) {
      bodyContent = const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 10),
            Text(
              'Cargando rutas...',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    } else if (rutasGuardadas!.isEmpty) {
      bodyContent = const Center(
        child: Text(
          "No hay rutas para mostrar",
          style: TextStyle(fontSize: 18, color: Colors.grey),
        ),
      );
    } else {
      bodyContent = ListView.builder(
        itemCount: rutasGuardadas!.length,
        itemBuilder: (context, index) {
          final ruta = rutasGuardadas![index];

          return Card(
            margin: const EdgeInsets.all(8.0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.0),
            ),
            elevation: 5,
            child: ListTile(
              title: Text(
                ruta['nombre'],
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ruta['descripcion']),
                  const SizedBox(height: 5),
                  Text('Dificultad: ${ruta['dificultad']}'),
                ],
              ),
              leading: const Icon(Icons.map, color: Color(0xFF50C9B5)),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () {
                  _confirmDelete(context, ruta['id']);
                },
              ),
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DetalleRutaScreen(ruta: ruta),
                  ),
                );

                if (result == true) {
                  _fetchRutas();
                }
              },
            ),
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF50C9B5),
        title: Row(
          children: [
            logoWhite,
            const SizedBox(width: 10),
            const Text('Listado de Rutas'),
          ],
        ),
      ),
      body: bodyContent,
    );
  }
}

// Pantalla para ver y editar los detalles de una ruta
class DetalleRutaScreen extends StatefulWidget {
  final Map<String, dynamic> ruta;

  const DetalleRutaScreen({super.key, required this.ruta});

  @override
  _DetalleRutaScreenState createState() => _DetalleRutaScreenState();
}

class _DetalleRutaScreenState extends State<DetalleRutaScreen> {
  bool _isEditing = false;
  late TextEditingController _nombreController;
  late TextEditingController _descripcionController;
  String? localUsername; // Username almacenado localmente
  bool esPropietario = false; // Variable para verificar si es el propietario
  List<dynamic>? usuariosFiltrados; // Lista filtrada de usuarios
  TextEditingController _searchController = TextEditingController(); // Controlador de búsqueda
  String? errorMessage; // Variable para mostrar mensajes de error

  @override
  void initState() {
    super.initState();
    _nombreController = TextEditingController(text: widget.ruta['nombre']);
    _descripcionController = TextEditingController(text: widget.ruta['descripcion']);
    _fetchLocalUsername(); // Obtener el username almacenado localmente
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _descripcionController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // Obtener el username almacenado localmente
  Future<void> _fetchLocalUsername() async {
    final username = await db.get('username'); // Obtener el username de la base de datos
    setState(() {
      localUsername = username as String?;
      esPropietario = (localUsername == widget.ruta['usuario']['username']); // Comparar con el username del creador de la ruta
    });
  }

  // Método para buscar usuarios solo cuando se presiona el botón de búsqueda
  Future<void> _fetchUsuarios() async {
    String query = _searchController.text.trim();

    if (query == '') {
      setState(() {
        errorMessage = '';
        usuariosFiltrados = null;
      });
      return;
    }

    await makeRequest(
      method: GET,
      url: 'api/users/search?q=$query', // Enviar la consulta al backend
      onOk: (response) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        setState(() {
          usuariosFiltrados = data;
          errorMessage = null; // Limpiar el mensaje de error si la búsqueda es exitosa
        });
      },
      onError: (response) {
        var errorData = jsonDecode(response.body);
        setState(() {
          errorMessage = errorData['error'];
          usuariosFiltrados = null; // Limpiar la lista si hay un error
        });
      },
      onConnectionError: (errorMessage) {
        setState(() {
          this.errorMessage = 'Error de conexión: $errorMessage';
          usuariosFiltrados = [];
        });
      },
    );
  }

  // Método para compartir la ruta con el usuario seleccionado
  Future<void> _compartirRutaConUsuario(int usuarioId) async {
    await makeRequest(
      method: POST,
      url: 'api/routes/${widget.ruta['id']}/share/$usuarioId/',
      onOk: (response) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ruta compartida exitosamente con el usuario $usuarioId')),
        );
      },
      onError: (response) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al compartir la ruta: Código ${response.statusCode}')),
        );
      },
      onConnectionError: (errorMessage) {
        // Imprimir el error en la consola para facilitar la depuración
        print("Error al compartir la ruta: $errorMessage");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error de conexión: $errorMessage')),
        );
      },
    );
  }

  // Mostrar lista de usuarios con campo de búsqueda
  void _showUsuariosBottomSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (text) async {
                            await _fetchUsuarios();
                            setModalState(() {}); // Actualizar el estado del modal
                          },
                          decoration: InputDecoration(
                            labelText: 'Buscar usuario',
                            prefixIcon: Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.search),
                        onPressed: () async {
                          await _fetchUsuarios();
                          setModalState(() {}); // Actualizar el estado del modal
                        },
                      ),
                    ],
                  ),
                ),
                if (errorMessage != null) // Mostrar el mensaje de error si existe
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      errorMessage!,
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                Expanded(
                  child: usuariosFiltrados == null
                      ? const Center(child: Text("Ingrese un término para buscar usuarios"))
                      : usuariosFiltrados!.isEmpty
                      ? const Center(child: Text("No se encontraron usuarios"))
                      : ListView.builder(
                    itemCount: usuariosFiltrados!.length,
                    itemBuilder: (context, index) {
                      final usuario = usuariosFiltrados![index];

                      return ListTile(
                        title: Text(usuario['username']),
                        onTap: () {
                          Navigator.pop(context); // Cierra el BottomSheet
                          _compartirRutaConUsuario(usuario['id']); // Llamar a compartir ruta con el usuario seleccionado
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            logoWhite,
            const SizedBox(width: 10),
            const Text("iTrek Editar Ruta"),
          ],
        ),
        backgroundColor: const Color(0xFF50C9B5),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nombreController,
              decoration: const InputDecoration(labelText: 'Nombre de la Ruta'),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              enabled: _isEditing, // Solo editable en modo edición
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _descripcionController,
              decoration: const InputDecoration(labelText: 'Descripción'),
              style: const TextStyle(fontSize: 16),
              enabled: _isEditing, // Solo editable en modo edición
            ),
            const SizedBox(height: 10),
            Text(
              'Dificultad: ${widget.ruta['dificultad']}',
              style: const TextStyle(fontSize: 16),
            ),
            const Spacer(),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF50C9B5),
                minimumSize: const Size(double.infinity, 50),
              ),
              onPressed: () {
                setState(() {
                  _isEditing = !_isEditing; // Cambiar entre editar y guardar
                });
              },
              child: Text(
                _isEditing ? 'Guardar' : 'Editar',
                style: const TextStyle(color: Colors.white, fontSize: 16.0),
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                minimumSize: const Size(double.infinity, 50),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RecorrerRutaScreen(
                      ruta: widget.ruta,
                    ),
                  ),
                );
              },
              child: const Text(
                'Recorrer Ruta',
                style: TextStyle(color: Colors.white, fontSize: 16.0),
              ),
            ),
            const SizedBox(height: 10),
            if (esPropietario) // Solo mostrar el botón si el usuario es el propietario
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  minimumSize: const Size(double.infinity, 50),
                ),
                onPressed: () {
                  _showUsuariosBottomSheet(); // Mostrar y buscar usuarios para compartir
                },
                child: const Text(
                  'Compartir Ruta',
                  style: TextStyle(color: Colors.white, fontSize: 16.0),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
