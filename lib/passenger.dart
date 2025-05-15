import 'package:flutter/material.dart';
import 'package:my_app/address.dart';
import 'package:my_app/map.dart';

class BookSeatPage extends StatefulWidget {
  @override
  _BookSeatPageState createState() => _BookSeatPageState();
}

class _BookSeatPageState extends State<BookSeatPage> {
  List<Map<String, dynamic>> savedAddresses = [];

  void _addNewAddress(Map<String, dynamic> address) {
    setState(() {
      savedAddresses.add(address);
    });
  }

  void _showAllOnMap() {
    if (savedAddresses.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapScreen(
          addresses: savedAddresses,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Passenger's List"),
        actions: [
          IconButton(
            icon: const Icon(Icons.map),
            onPressed: _showAllOnMap,
            tooltip: 'View on Map',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              final result = await showDialog(
                context: context,
                builder: (context) => AddressEntryDialog(),
              );
              if (result != null) _addNewAddress(result);
            },
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: savedAddresses.length,
        itemBuilder: (context, index) {
          final address = savedAddresses[index];
          return AddressCard(
            from: address['from']['address'],
            to: address['to']['address'],
            onDelete: () => setState(() => savedAddresses.removeAt(index)),
          );
        },
      ),
    );
  }
}



