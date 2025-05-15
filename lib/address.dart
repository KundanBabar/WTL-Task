import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/material.dart';

class AddressEntryDialog extends StatefulWidget {
  @override
  _AddressEntryDialogState createState() => _AddressEntryDialogState();
}

class _AddressEntryDialogState extends State<AddressEntryDialog> {
  Map<String, dynamic> _fromAddress = {};
  Map<String, dynamic> _toAddress = {};

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Choose your Journey'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AddressSearchField(
              label: 'From',
              onAddressSelected: (address) => _fromAddress = address,
            ),
            SizedBox(height: 20),
            AddressSearchField(
              label: 'To',
              onAddressSelected: (address) => _toAddress = address,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_fromAddress.isNotEmpty && _toAddress.isNotEmpty) {
              Navigator.pop(context, {
                'from': _fromAddress,
                'to': _toAddress
              });
            }
          },
          child: Text('Save'),
        ),
      ],
    );
  }
}

class AddressSearchField extends StatefulWidget {
  final String label;
  final Function(Map<String, dynamic>) onAddressSelected;

  const AddressSearchField({
    required this.label,
    required this.onAddressSelected,
  });

  @override
  _AddressSearchFieldState createState() => _AddressSearchFieldState();
}

class _AddressSearchFieldState extends State<AddressSearchField> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<dynamic> _predictions = [];
  Timer? _debounce;
  bool _isLoading = false;

  static const String _apiKey = 'AIzaSyB7krJjitH00FhPStq5wV_h4taB-0U2-dM';
  static const String _autocompleteUrl = 'https://maps.googleapis.com/maps/api/place/autocomplete/json';
  static const String _detailsUrl = 'https://maps.googleapis.com/maps/api/place/details/json';

  Future<Map<String, dynamic>> _getPlaceDetails(String placeId) async {
    final response = await http.get(
      Uri.parse('$_detailsUrl?place_id=$placeId&key=$_apiKey'),
    );

    final data = json.decode(response.body);
    if (data['status'] == 'OK') {
      final result = data['result'];
      final location = result['geometry']['location'];
      return {
        'address': result['formatted_address'],
        'lat': location['lat'],
        'lng': location['lng'],
      };
    }
    return {};
  }

  void _searchPlaces(String input) async {
    if (input.length < 3) {
      setState(() => _predictions = []);
      return;
    }

    final params = {
      'input': input,
      'key': _apiKey,
      'components': 'country:in',
      'language': 'en',
      'types': 'geocode',
      'region': 'in'
    };

    try {
      setState(() => _isLoading = true);

      final response = await http.get(
          Uri.parse(_autocompleteUrl).replace(queryParameters: params)
      );

      final data = json.decode(response.body);

      if (data['status'] == 'OK') {
        setState(() => _predictions = data['predictions']);
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: TextStyle(fontWeight: FontWeight.bold)),
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          decoration: InputDecoration(
            hintText: 'Enter ${widget.label.toLowerCase()} address',
            suffixIcon: _isLoading
                ? CircularProgressIndicator()
                : Icon(Icons.search),
          ),
          onChanged: (query) {
            if (_debounce?.isActive ?? false) _debounce?.cancel();
            _debounce = Timer(Duration(milliseconds: 500), () {
              _searchPlaces(query);
            });
          },
        ),
        if (_predictions.isNotEmpty)
          ..._predictions.map((prediction) => ListTile(
            title: Text(prediction['description']),
            onTap: () async {
              final details = await _getPlaceDetails(prediction['place_id']);
              if (details.isNotEmpty) {
                _controller.text = details['address'];
                widget.onAddressSelected(details);
                setState(() => _predictions = []);
                _focusNode.unfocus();
              }
            },
          )).toList(),
      ],
    );
  }
}

class AddressCard extends StatelessWidget {
  final String from;
  final String to;
  final VoidCallback onDelete;

  const AddressCard({
    required this.from,
    required this.to,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      child: ListTile(
        title: Text('From: $from'),
        subtitle: Text('To: $to'),
        trailing: IconButton(
          icon: Icon(Icons.delete),
          onPressed: onDelete,
        ),
        dense: true,
      ),
    );
  }
}