// ignore_for_file: unused_element, unused_field, prefer_final_fields, curly_braces_in_flow_control_structures, deprecated_member_use
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const ShopEstimatorApp());
}

class PurchasePage extends StatefulWidget {
  const PurchasePage({super.key});

  @override
  State<PurchasePage> createState() => _PurchasePageState();
}

class PurchaseItem {
  final ProductMaster product;
  final TextEditingController qtyController;
  final TextEditingController rateController;
  final TextEditingController unitController;
  int qty;

  PurchaseItem({required this.product, this.qty = 1})
    : qtyController = TextEditingController(text: qty.toString()),
      rateController = TextEditingController(
        text: product.purchasePrice.toStringAsFixed(2),
      ),
      unitController = TextEditingController(text: product.unit);

  double get rate =>
      double.tryParse(rateController.text) ?? product.purchasePrice;
  double get total => qty * rate;

  void dispose() {
    qtyController.dispose();
    rateController.dispose();
    unitController.dispose();
  }
}

class _PurchasePageState extends State<PurchasePage> {
  final _formKey = GlobalKey<FormState>();
  final _supplierController = TextEditingController();
  final _searchController = TextEditingController();
  final _dateController = TextEditingController();
  final _purController = TextEditingController();

  String _searchQuery = '';
  int _lastPurchaseNumber = 0;
  String _purNo = 'PUR-0001';
  String _purchaseDate = '';

  final List<ProductMaster> _availableProducts = [];
  final List<ProductMaster> _filteredProducts = [];
  final List<PurchaseItem> _items = [];
  final List<Map<String, String>> _supplierParties = [];
  final List<Map<String, String>> _filteredSupplierParties = [];
  double get _grandTotal {
    double total = 0;
    for (final item in _items) {
      final qty = int.tryParse(item.qtyController.text) ?? 0;
      final rate = double.tryParse(item.rateController.text) ?? 0;
      total += qty * rate;
    }
    return total;
  }

  void _setQty(PurchaseItem item, int qty) {
    if (qty < 1) qty = 1;

    final text = qty.toString();

    setState(() {
      item.qty = qty;
      item.qtyController.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    });
  }

  void _deleteItem(int index) {
    setState(() {
      _items[index].dispose();
      _items.removeAt(index);
    });
  }

  @override
  void initState() {
    super.initState();
    _purchaseDate = _formatDate(DateTime.now());
    _dateController.text = _purchaseDate;
    _searchController.addListener(() => _updateSearch(_searchController.text));
    _loadAvailableProducts();
    _loadLastPurchaseNumber();
    _loadSupplierParties();
  }

  Future<void> _loadSupplierParties() async {
    final prefs = await SharedPreferences.getInstance();
    final savedParties = prefs.getString('parties_list');
    if (savedParties == null || savedParties.isEmpty) return;

    final dynamic decodedParties;
    try {
      decodedParties = jsonDecode(savedParties);
    } catch (_) {
      return;
    }
    if (decodedParties is! List) return;

    final parties = decodedParties
        .whereType<Map>()
        .map(
          (party) => party.map(
            (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
          ),
        )
        .where(
          (party) =>
              party['partyType'] == 'Supplier' || party['partyType'] == 'Both',
        )
        .toList();

    if (!mounted) return;
    setState(() {
      _supplierParties
        ..clear()
        ..addAll(parties);
    });
  }

  void _updateSupplierPartySuggestions(String query) {
    final text = query.trim().toLowerCase();
    setState(() {
      if (text.isEmpty) {
        _filteredSupplierParties.clear();
      } else {
        _filteredSupplierParties
          ..clear()
          ..addAll(
            _supplierParties.where((party) {
              final partyName = (party['partyName'] ?? '').toLowerCase();
              final mobile = (party['mobileNumber'] ?? '').toLowerCase();
              return partyName.contains(text) || mobile.contains(text);
            }),
          );
      }
    });
  }

  void _selectSupplierParty(Map<String, String> party) {
    setState(() {
      _supplierController.text = party['partyName'] ?? '';
      _filteredSupplierParties.clear();
    });
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day-$month-$year';
  }

  String _formatPurNo(int value) => 'PUR-${value.toString().padLeft(4, "0")}';

  Future<void> _loadLastPurchaseNumber() async {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getInt('last_purchase_number') ?? 0;
    setState(() {
      _lastPurchaseNumber = last;
      _purNo = _formatPurNo(_lastPurchaseNumber + 1);
      _purController.text = _purNo;
    });
  }

  Future<void> _loadAvailableProducts() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('product_master_list') ?? [];
    final productMap = <String, ProductMaster>{};
    for (final entry in saved) {
      final product = ProductMaster.fromJson(
        jsonDecode(entry) as Map<String, dynamic>,
      );
      final key = product.productCode.trim().toLowerCase();
      if (key.isEmpty) continue;
      productMap[key] = product;
    }
    setState(() {
      _availableProducts.clear();
      _availableProducts.addAll(productMap.values);
      _filteredProducts.clear();
      _filteredProducts.addAll(_availableProducts);
    });
  }

  void _updateSearch(String query) {
    final text = query.trim().toLowerCase();
    setState(() {
      _searchQuery = query;
      if (text.isEmpty) {
        _filteredProducts.clear();
      } else {
        _filteredProducts
          ..clear()
          ..addAll(
            _availableProducts.where((p) {
              final code = p.productCode.toLowerCase();
              final name = p.productName.toLowerCase();
              return code.contains(text) || name.contains(text);
            }),
          );
      }
    });
  }

  void _selectProduct(ProductMaster product) {
    final key = product.productCode.trim().toLowerCase();
    final existingIndex = _items.indexWhere(
      (it) => it.product.productCode.trim().toLowerCase() == key,
    );
    setState(() {
      if (existingIndex >= 0) {
        final it = _items[existingIndex];
        it.qty += 1;
        it.qtyController.text = it.qty.toString();
      } else {
        _items.add(PurchaseItem(product: product));
      }
      _searchController.clear();
      _filteredProducts.clear();
      _searchQuery = '';
    });
  }

  Future<void> _savePurchase() async {
    // Validate purchase number is not empty
    final purNo = _purController.text.trim();
    if (purNo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Purchase number cannot be empty')),
      );
      return;
    }

    if (_items.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Add at least one product')));
      return;
    }

    for (final it in _items) {
      final qty = int.tryParse(it.qtyController.text.trim()) ?? 0;
      final rate = double.tryParse(it.rateController.text.trim()) ?? 0;

      it.qty = qty;

      if (qty <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Quantity must be greater than 0')),
        );
        return;
      }

      if (rate <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Purchase rate must be greater than 0')),
        );
        return;
      }
    }

    final prefs = await SharedPreferences.getInstance();

    // Check if purchase number already exists
    final existingHistory = prefs.getStringList('purchase_history_list') ?? [];
    final purNoExists = existingHistory.any((entry) {
      final bill = PurchaseBill.fromJson(
        jsonDecode(entry) as Map<String, dynamic>,
      );
      return bill.purchaseNo == purNo;
    });

    if (purNoExists) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Purchase number already exists')),
      );
      return;
    }

    // Create purchase bill with item-level rates
    final purchaseBill = PurchaseBill(
      purchaseNo: purNo,
      purchaseDate: _dateController.text.trim(),
      supplierName: _supplierController.text.trim(),
      grandTotal: _grandTotal,
      items: _items
          .map(
            (it) => PurchaseBillItem(
              productCode: it.product.productCode,
              productName: it.product.productName,
              unit: it.unitController.text.trim(),
              quantity: it.qty,
              purchaseRate: it.rate,
              total: it.total,
            ),
          )
          .toList(),
    );

    // Save purchase bill to purchase_history_list
    existingHistory.insert(0, jsonEncode(purchaseBill.toJson()));
    await prefs.setStringList('purchase_history_list', existingHistory);

    // Save purchase-wise stock lots
    final lotSaved = prefs.getStringList('purchase_stock_lot_list') ?? [];
    final lotList = lotSaved
        .map(
          (s) =>
              PurchaseStockLot.fromJson(jsonDecode(s) as Map<String, dynamic>),
        )
        .toList();

    int nextLotNumber = lotList.length + 1;

    for (final it in _items) {
      final qty = int.tryParse(it.qtyController.text.trim()) ?? 0;
      final rate = double.tryParse(it.rateController.text.trim()) ?? 0;

      final lotNo =
          '${it.product.productCode}-B${nextLotNumber.toString().padLeft(3, '0')}';

      lotList.insert(
        0,
        PurchaseStockLot(
          lotNo: lotNo,
          purchaseNo: _purController.text.trim(),
          purchaseDate: _dateController.text.trim(),
          supplierName: _supplierController.text.trim(),
          productCode: it.product.productCode,
          productName: it.product.productName,
          unit: it.product.unit,
          qty: qty,
          remainingQty: qty,
          purchaseRate: rate,
        ),
      );

      nextLotNumber++;
    }

    // Save stock lots
    await prefs.setStringList(
      'purchase_stock_lot_list',
      lotList.map((e) => jsonEncode(e.toJson())).toList(),
    );

    // Update Product Master total stock only
    final prodSaved = prefs.getStringList('product_master_list') ?? [];
    final prodList = prodSaved
        .map(
          (s) => ProductMaster.fromJson(jsonDecode(s) as Map<String, dynamic>),
        )
        .toList();

    for (final it in _items) {
      final qty = int.tryParse(it.qtyController.text.trim()) ?? 0;
      final key = it.product.productCode.trim().toLowerCase();

      final idx = prodList.indexWhere(
        (p) => p.productCode.trim().toLowerCase() == key,
      );

      if (idx != -1) {
        final p = prodList[idx];

        prodList[idx] = ProductMaster(
          productCode: p.productCode,
          productName: p.productName,
          category: p.category,
          unit: p.unit,
          purchasePrice: p.purchasePrice,
          mrpPrice: p.mrpPrice,
          defaultSalePrice: p.defaultSalePrice,
          minimumStockAlert: p.minimumStockAlert,
          currentStock: p.currentStock + qty,
        );
      }
    }

    await prefs.setStringList(
      'product_master_list',
      prodList.map((p) => jsonEncode(p.toJson())).toList(),
    );

    await _updateSelectedSupplierPayableBalance();

    // increment last purchase number
    final current = _lastPurchaseNumber + 1;
    await prefs.setInt('last_purchase_number', current);
    _lastPurchaseNumber = current;

    // clear form
    setState(() {
      for (final it in _items) {
        it.dispose();
      }
      _items.clear();
      _supplierController.clear();
      _purchaseDate = _formatDate(DateTime.now());
      _dateController.text = _purchaseDate;
      _purNo = _formatPurNo(_lastPurchaseNumber + 1);
      _purController.text = _purNo;
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        width: 320,
        content: Center(
          child: Text(
            'Purchase saved successfully',
            style: TextStyle(
              color: kPrimaryBlue,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
    await _loadAvailableProducts();
  }

  Future<void> _updateSelectedSupplierPayableBalance() async {
    final purchaseBalance = _grandTotal;
    final supplierName = _supplierController.text.trim();
    if (purchaseBalance <= 0 || supplierName.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final savedParties = prefs.getString('parties_list');
    if (savedParties == null || savedParties.isEmpty) return;

    final dynamic decodedParties;
    try {
      decodedParties = jsonDecode(savedParties);
    } catch (_) {
      return;
    }
    if (decodedParties is! List) return;

    final supplierKey = supplierName.toLowerCase();
    var updated = false;
    final updatedParties = decodedParties.map((party) {
      if (party is! Map) return party;

      final partyMap = Map<String, dynamic>.from(party);
      final partyName = (partyMap['partyName'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      final partyType = (partyMap['partyType'] ?? '').toString();
      final isSupplierParty = partyType == 'Supplier' || partyType == 'Both';
      if (updated || !isSupplierParty || partyName != supplierKey)
        return partyMap;

      final existingBalance =
          double.tryParse((partyMap['openingBalance'] ?? '0').toString()) ??
          0.0;
      partyMap['openingBalance'] = (existingBalance + purchaseBalance)
          .toStringAsFixed(2);
      partyMap['balanceType'] = 'Payable';
      updated = true;
      return partyMap;
    }).toList();

    if (updated) {
      await prefs.setString('parties_list', jsonEncode(updatedParties));
    }
  }

  Widget _buildSupplierPartySuggestions() {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 220),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: SingleChildScrollView(
        child: Column(
          children: _filteredSupplierParties.map((party) {
            final partyName = party['partyName'] ?? '';
            final mobile = party['mobileNumber'] ?? '';
            final category = party['category'] ?? '';
            return InkWell(
              onTap: () => _selectSupplierParty(party),
              child: SizedBox(
                height: 52,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          partyName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: kPrimaryBlue,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          [
                            mobile,
                            category,
                          ].where((value) => value.isNotEmpty).join(' | '),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _supplierController.dispose();
    _searchController.dispose();
    _dateController.dispose();
    _purController.dispose();
    for (final it in _items) {
      it.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchase Entry'),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final maxWidth = width > 1000 ? 980.0 : double.infinity;
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      color: kCardBlue,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Purchase Details',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: kPrimaryBlue,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _dateController,
                                      decoration: InputDecoration(
                                        labelText: 'Date',
                                        filled: true,
                                        fillColor: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _purController,
                                      decoration: InputDecoration(
                                        labelText: 'Purchase No',
                                        filled: true,
                                        fillColor: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _supplierController,
                                decoration: InputDecoration(
                                  labelText: 'Supplier / Party',
                                  hintText: 'Supplier name',
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                                onChanged: _updateSupplierPartySuggestions,
                              ),
                              if (_filteredSupplierParties.isNotEmpty)
                                const SizedBox(height: 8),
                              if (_filteredSupplierParties.isNotEmpty)
                                _buildSupplierPartySuggestions(),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _searchController,
                                decoration: InputDecoration(
                                  labelText:
                                      'Search product code or product name',
                                  filled: true,
                                  fillColor: Colors.white,
                                  suffixIcon: _searchQuery.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.clear),
                                          onPressed: () =>
                                              _searchController.clear(),
                                        )
                                      : null,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                ),
                                onChanged: _updateSearch,
                              ),
                              const SizedBox(height: 8),
                              if (_searchQuery.isNotEmpty)
                                Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  child: _filteredProducts.isEmpty
                                      ? const Padding(
                                          padding: EdgeInsets.all(12),
                                          child: Text(
                                            'No products match your search.',
                                            style: TextStyle(
                                              color: Color(0xFF64748B),
                                            ),
                                          ),
                                        )
                                      : Column(
                                          children: _filteredProducts.map((
                                            product,
                                          ) {
                                            return InkWell(
                                              onTap: () =>
                                                  _selectProduct(product),
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 10,
                                                    ),
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        '${product.productCode} - ${product.productName}',
                                                        style: const TextStyle(
                                                          fontSize: 13,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color: kPrimaryBlue,
                                                        ),
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      'Stock: ${product.currentStock}',
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        color: Color(
                                                          0xFF64748B,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      color: kLightBlue,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Purchase Items',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: kPrimaryBlue,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (_items.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Center(
                                  child: Text(
                                    'Add products to start the purchase.',
                                    style: TextStyle(color: Color(0xFF64748B)),
                                  ),
                                ),
                              )
                            else
                              Column(
                                children: List.generate(_items.length, (index) {
                                  final it = _items[index];
                                  return Container(
                                    width: double.infinity,
                                    margin: const EdgeInsets.only(bottom: 4),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.grey.shade200,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '${it.product.productCode} - ${it.product.productName}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: kPrimaryBlue,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        SizedBox(
                                          width: 90,
                                          height: 44,
                                          child: DropdownButtonFormField<String>(
                                            isExpanded: true,
                                            isDense: true,
                                            value:
                                                const [
                                                  'Nos',
                                                  'Bag',
                                                  'Box',
                                                  'Feet',
                                                  'Kg',
                                                  'Liter',
                                                  'Other',
                                                ].contains(
                                                  it.unitController.text,
                                                )
                                                ? it.unitController.text
                                                : 'Nos',
                                            decoration: InputDecoration(
                                              labelText: 'Unit',
                                              filled: true,
                                              fillColor: Colors.white,
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 6,
                                                  ),
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                borderSide: BorderSide(
                                                  color: Colors.grey.shade300,
                                                ),
                                              ),
                                            ),
                                            items:
                                                const [
                                                      'Nos',
                                                      'Bag',
                                                      'Box',
                                                      'Feet',
                                                      'Kg',
                                                      'Liter',
                                                      'Other',
                                                    ]
                                                    .map(
                                                      (unit) =>
                                                          DropdownMenuItem(
                                                            value: unit,
                                                            child: Text(unit),
                                                          ),
                                                    )
                                                    .toList(),
                                            onChanged: (value) {
                                              if (value == null) return;
                                              setState(() {
                                                it.unitController.text = value;
                                              });
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        SizedBox(
                                          width: 120,
                                          height: 44,
                                          child: TextFormField(
                                            controller: it.rateController,
                                            keyboardType:
                                                const TextInputType.numberWithOptions(
                                                  decimal: true,
                                                ),
                                            decoration: InputDecoration(
                                              labelText: 'Purchase',
                                              filled: true,
                                              fillColor: Colors.white,
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 12,
                                                  ),
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                borderSide: BorderSide(
                                                  color: Colors.grey.shade300,
                                                ),
                                              ),
                                            ),
                                            onChanged: (_) => setState(() {}),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          width: 132,
                                          height: 44,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            border: Border.all(
                                              color: Colors.grey.shade300,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              IconButton(
                                                onPressed: it.qty > 1
                                                    ? () => _setQty(
                                                        it,
                                                        it.qty - 1,
                                                      )
                                                    : null,
                                                icon: const Icon(
                                                  Icons.remove,
                                                  size: 18,
                                                ),
                                                padding: EdgeInsets.zero,
                                                constraints:
                                                    const BoxConstraints.tightFor(
                                                      width: 32,
                                                      height: 32,
                                                    ),
                                              ),
                                              SizedBox(
                                                width: 40,
                                                child: TextFormField(
                                                  controller: it.qtyController,
                                                  onTap: () {
                                                    it.qtyController.selection =
                                                        TextSelection(
                                                          baseOffset: 0,
                                                          extentOffset: it
                                                              .qtyController
                                                              .text
                                                              .length,
                                                        );
                                                  },
                                                  onChanged: (value) {
                                                    final qty = int.tryParse(
                                                      value.trim(),
                                                    );
                                                    if (qty == null || qty < 1)
                                                      return;
                                                    setState(() {
                                                      it.qty = qty;
                                                    });
                                                  },
                                                  keyboardType:
                                                      TextInputType.number,
                                                  textAlign: TextAlign.center,
                                                  decoration:
                                                      const InputDecoration(
                                                        border:
                                                            InputBorder.none,
                                                        isDense: true,
                                                      ),
                                                ),
                                              ),
                                              IconButton(
                                                onPressed: () =>
                                                    _setQty(it, it.qty + 1),
                                                icon: const Icon(
                                                  Icons.add,
                                                  size: 18,
                                                ),
                                                padding: EdgeInsets.zero,
                                                constraints:
                                                    const BoxConstraints.tightFor(
                                                      width: 32,
                                                      height: 32,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          width: 110,
                                          height: 50,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: kLightBlue,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              const Text(
                                                'Total',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: Color(0xFF64748B),
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '₹${it.total.toStringAsFixed(2)}',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color: kPrimaryBlue,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        SizedBox(
                                          width: 40,
                                          height: 40,
                                          child: IconButton(
                                            onPressed: () => _deleteItem(index),
                                            padding: EdgeInsets.zero,
                                            icon: const Icon(
                                              Icons.delete_outline,
                                              color: Colors.redAccent,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        SizedBox(
                                          width: 70,
                                          height: 40,
                                          child: Align(
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                              'Stock: ${it.product.currentStock}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Color(0xFF64748B),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      color: kLightBlue,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Grand Total',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF475467),
                                  ),
                                ),
                                Text(
                                  '₹${_grandTotal.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: kPrimaryBlue,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: FilledButton(
                                onPressed: _savePurchase,
                                style: FilledButton.styleFrom(
                                  backgroundColor: kPrimaryBlue,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: const Text(
                                  'Save Purchase',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

const Color kPrimaryBlue = Color(0xFF1565C0);
const Color kCardBlue = Color(0xFFE8F1FF);
const Color kLightGray = Color(0xFFF4F7FB);
const Color kLightBlue = Color(0xFFE3F2FD);
const Color kGreen = Color(0xFFE8F5E9);
const Color kOrange = Color(0xFFFFF3E0);
const Color kPurple = Color(0xFFF3E5F5);
const Color kRedLight = Color(0xFFFFEBEE);

class ShopEstimatorApp extends StatelessWidget {
  const ShopEstimatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shop Estimator',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: kPrimaryBlue,
          brightness: Brightness.light,
          primary: kPrimaryBlue,
          secondary: kPrimaryBlue,
          surface: Colors.white,
        ),
        useMaterial3: true,
        splashFactory: NoSplash.splashFactory,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        focusColor: Colors.transparent,
        textButtonTheme: TextButtonThemeData(
          style: ButtonStyle(
            overlayColor: WidgetStateProperty.all(Colors.transparent),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: ButtonStyle(
            overlayColor: WidgetStateProperty.all(Colors.transparent),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: ButtonStyle(
            overlayColor: WidgetStateProperty.all(Colors.transparent),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ButtonStyle(
            overlayColor: WidgetStateProperty.all(Colors.transparent),
          ),
        ),
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: kPrimaryBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          toolbarHeight: 72,
          surfaceTintColor: kPrimaryBlue,
        ),
        cardTheme: const CardThemeData(
          color: kCardBlue,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
        textTheme: const TextTheme(
          headlineSmall: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: kPrimaryBlue,
          ),
          titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          bodyLarge: TextStyle(fontSize: 15, color: Color(0xFF475467)),
          bodyMedium: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
        ),
      ),
      home: const DashboardPage(),
    );
  }
}

class MyApp extends ShopEstimatorApp {
  const MyApp({super.key});
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  static final List<_SummaryItem> _summaryItems = [
    _SummaryItem(
      label: "Today's Sales",
      value: '₹42,800',
      icon: Icons.point_of_sale,
      color: kLightBlue,
    ),
    _SummaryItem(
      label: "Today's Purchase",
      value: '₹18,400',
      icon: Icons.shopping_cart_checkout,
      color: kGreen,
    ),
    _SummaryItem(
      label: 'Stock Value',
      value: '₹312,700',
      icon: Icons.inventory_2,
      color: kOrange,
    ),
    _SummaryItem(
      label: 'Receivable',
      value: '₹72,300',
      icon: Icons.account_balance_wallet,
      color: kPurple,
    ),
    _SummaryItem(
      label: 'Payable',
      value: '₹24,100',
      icon: Icons.payments,
      color: kRedLight,
    ),
  ];

  static const List<_MenuItem> _menuItems = [
    _MenuItem(label: 'Company', icon: Icons.business),
    _MenuItem(label: 'Parties', icon: Icons.group),
    _MenuItem(label: 'Bank Accounts', icon: Icons.account_balance),
    _MenuItem(label: 'Purchase', icon: Icons.shopping_bag),
    _MenuItem(label: 'Purchase Return', icon: Icons.undo),
    _MenuItem(label: 'Product Master', icon: Icons.category),
    _MenuItem(label: 'Inventory', icon: Icons.storefront),
    _MenuItem(label: 'Sales', icon: Icons.sell),
    _MenuItem(label: 'Sales Return', icon: Icons.keyboard_return),
    _MenuItem(label: 'Reports', icon: Icons.bar_chart),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'SHOP ESTIMATOR',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Smart Inventory & Billing',
              style: TextStyle(fontSize: 13, color: Color(0xFFBBDEFB)),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: CircleAvatar(
              radius: 20,
              backgroundColor: Colors.white,
              child: const Icon(Icons.business_center, color: kPrimaryBlue),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final summaryColumns = width >= 1400
                ? 5
                : width >= 1200
                ? 4
                : width >= 1000
                ? 3
                : width >= 700
                ? 2
                : 1;
            final menuColumns = width >= 1200
                ? 4
                : width >= 900
                ? 3
                : width >= 600
                ? 2
                : 1;

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Dashboard Overview',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: kPrimaryBlue,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'A clear overview of sales, inventory, receivables and payable positions.',
                    style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _summaryItems.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: summaryColumns,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      mainAxisExtent: 65,
                    ),
                    itemBuilder: (context, index) {
                      return _SummaryCard(item: _summaryItems[index]);
                    },
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Quick Actions',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: kPrimaryBlue,
                    ),
                  ),
                  const SizedBox(height: 10),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _menuItems.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: menuColumns,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      mainAxisExtent: 90,
                    ),
                    itemBuilder: (context, index) {
                      return _MenuCard(item: _menuItems[index]);
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SummaryItem {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
}

class _MenuItem {
  final String label;
  final IconData icon;

  const _MenuItem({required this.label, required this.icon});
}

class _SummaryCard extends StatelessWidget {
  final _SummaryItem item;

  const _SummaryCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: item.color,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        splashColor: Colors.black.withAlpha(10),
        highlightColor: Colors.black.withAlpha(5),
        radius: 18,
        enableFeedback: false,
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    height: 28,
                    width: 28,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(item.icon, color: kPrimaryBlue, size: 15.0),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        item.value,
                        style: TextStyle(
                          fontSize: 15.0,
                          fontWeight: FontWeight.w900,
                          color: kPrimaryBlue,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Flexible(
                fit: FlexFit.loose,
                child: Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 11.0,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF263238),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final _MenuItem item;

  const _MenuCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kCardBlue,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        splashColor: Colors.black.withAlpha(10),
        highlightColor: Colors.black.withAlpha(5),
        radius: 20,
        enableFeedback: false,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) {
                if (item.label == 'Company') return const CompanyProfilePage();
                if (item.label == 'Parties') return const PartiesPage();
                if (item.label == 'Sales') return const SalesDashboardPage();
                if (item.label == 'Purchase') return const PurchasePage();
                if (item.label == 'Sales Return')
                  return const SalesReturnPage();
                if (item.label == 'Product Master')
                  return const ProductMasterPage();
                if (item.label == 'Inventory') return const InventoryPage();
                return SectionPage(title: item.label);
              },
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final iconSize = 18.0;
              final titleSize = 13.0;
              final subtitleSize = 11.0;
              return Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        height: 32,
                        width: 32,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          item.icon,
                          color: kPrimaryBlue,
                          size: iconSize,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          item.label,
                          style: TextStyle(
                            fontSize: titleSize,
                            fontWeight: FontWeight.w700,
                            color: kPrimaryBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap to manage',
                    style: TextStyle(
                      fontSize: subtitleSize,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class CompanyProfilePage extends StatefulWidget {
  const CompanyProfilePage({super.key});

  @override
  State<CompanyProfilePage> createState() => _CompanyProfilePageState();
}

class _CompanyProfilePageState extends State<CompanyProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _companyNameController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _alternateMobileController = TextEditingController();
  final _addressController = TextEditingController();
  final _gstinController = TextEditingController();
  final _emailController = TextEditingController();
  final _websiteController = TextEditingController();
  String _gstAvailable = 'No';
  bool _loading = true;
  bool _showCompanySaveSuccessMessage = false;

  @override
  void initState() {
    super.initState();
    _loadCompanyDetails();
  }

  Future<void> _loadCompanyDetails() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _companyNameController.text = prefs.getString('company_name') ?? '';
      _ownerNameController.text = prefs.getString('owner_name') ?? '';
      _mobileController.text = prefs.getString('mobile_number') ?? '';
      _alternateMobileController.text =
          prefs.getString('alternate_mobile') ?? '';
      _addressController.text = prefs.getString('address') ?? '';
      _gstAvailable = prefs.getString('gst_available') ?? 'No';
      _gstinController.text = prefs.getString('gstin') ?? '';
      _emailController.text = prefs.getString('email') ?? '';
      _websiteController.text = prefs.getString('website') ?? '';
      _loading = false;
    });
  }

  Future<void> _saveCompanyDetails() async {
    if (!_formKey.currentState!.validate()) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('company_name', _companyNameController.text.trim());
    await prefs.setString('owner_name', _ownerNameController.text.trim());
    await prefs.setString('mobile_number', _mobileController.text.trim());
    await prefs.setString(
      'alternate_mobile',
      _alternateMobileController.text.trim(),
    );
    await prefs.setString('address', _addressController.text.trim());
    await prefs.setString('gst_available', _gstAvailable);
    await prefs.setString('gstin', _gstinController.text.trim());
    await prefs.setString('email', _emailController.text.trim());
    await prefs.setString('website', _websiteController.text.trim());

    if (!mounted) return;
    setState(() {
      _showCompanySaveSuccessMessage = true;
    });
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() {
        _showCompanySaveSuccessMessage = false;
      });
    });
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _ownerNameController.dispose();
    _mobileController.dispose();
    _alternateMobileController.dispose();
    _addressController.dispose();
    _gstinController.dispose();
    _emailController.dispose();
    _websiteController.dispose();
    super.dispose();
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    int maxLines = 1,
    bool enabled = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        enabled: enabled,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Company Profile'), elevation: 0),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kPrimaryBlue))
          : LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final maxWidth = width > 900 ? 750.0 : double.infinity;
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxWidth),
                      child: Card(
                        color: kCardBlue,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Company Details',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: kPrimaryBlue,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Update company profile and contact details for your estimation workflow.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Form(
                                key: _formKey,
                                child: Column(
                                  children: [
                                    _buildTextField(
                                      label: 'Company Name *',
                                      controller: _companyNameController,
                                      validator: (value) =>
                                          value == null || value.trim().isEmpty
                                          ? 'Company name is required'
                                          : null,
                                    ),
                                    _buildTextField(
                                      label: 'Owner Name',
                                      controller: _ownerNameController,
                                    ),
                                    _buildTextField(
                                      label: 'Mobile Number *',
                                      controller: _mobileController,
                                      keyboardType: TextInputType.phone,
                                      validator: (value) =>
                                          value == null || value.trim().isEmpty
                                          ? 'Mobile number is required'
                                          : null,
                                    ),
                                    _buildTextField(
                                      label: 'Alternate Mobile',
                                      controller: _alternateMobileController,
                                      keyboardType: TextInputType.phone,
                                    ),
                                    _buildTextField(
                                      label: 'Address',
                                      controller: _addressController,
                                      maxLines: 3,
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 10,
                                      ),
                                      child: Builder(
                                        builder: (context) {
                                          final GlobalKey gstAvailableKey =
                                              GlobalKey();

                                          return GestureDetector(
                                            key: gstAvailableKey,
                                            behavior: HitTestBehavior.opaque,
                                            onTap: () {
                                              final RenderBox button =
                                                  gstAvailableKey
                                                          .currentContext!
                                                          .findRenderObject()
                                                      as RenderBox;
                                              final OverlayState overlay =
                                                  Overlay.of(context);
                                              final RenderBox overlayBox =
                                                  overlay.context
                                                          .findRenderObject()
                                                      as RenderBox;

                                              final Offset position = button
                                                  .localToGlobal(
                                                    Offset.zero,
                                                    ancestor: overlayBox,
                                                  );

                                              late OverlayEntry popupEntry;
                                              popupEntry = OverlayEntry(
                                                builder: (context) {
                                                  return Stack(
                                                    children: [
                                                      Positioned.fill(
                                                        child: GestureDetector(
                                                          behavior:
                                                              HitTestBehavior
                                                                  .opaque,
                                                          onTap:
                                                              popupEntry.remove,
                                                          child: Container(
                                                            color: Colors
                                                                .transparent,
                                                          ),
                                                        ),
                                                      ),
                                                      Positioned(
                                                        left: position.dx,
                                                        top:
                                                            position.dy +
                                                            button.size.height,
                                                        width:
                                                            button.size.width,
                                                        child: Material(
                                                          color: Colors
                                                              .transparent,
                                                          child: Container(
                                                            width: button
                                                                .size
                                                                .width,
                                                            decoration:
                                                                BoxDecoration(
                                                                  color: Colors
                                                                      .white,
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                        14,
                                                                      ),
                                                                  border: Border.all(
                                                                    color: Colors
                                                                        .grey
                                                                        .shade300,
                                                                  ),
                                                                ),
                                                            clipBehavior:
                                                                Clip.antiAlias,
                                                            child: Column(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .min,
                                                              children:
                                                                  ['Yes', 'No'].map((
                                                                    gstAvailable,
                                                                  ) {
                                                                    return GestureDetector(
                                                                      behavior:
                                                                          HitTestBehavior
                                                                              .opaque,
                                                                      onTap: () {
                                                                        popupEntry
                                                                            .remove();
                                                                        setState(() {
                                                                          _gstAvailable =
                                                                              gstAvailable;
                                                                        });
                                                                      },
                                                                      child: Container(
                                                                        width: button
                                                                            .size
                                                                            .width,
                                                                        height: button
                                                                            .size
                                                                            .height,
                                                                        padding: const EdgeInsets.symmetric(
                                                                          horizontal:
                                                                              12,
                                                                          vertical:
                                                                              10,
                                                                        ),
                                                                        alignment:
                                                                            Alignment.centerLeft,
                                                                        child: Text(
                                                                          gstAvailable,
                                                                          style: Theme.of(
                                                                            context,
                                                                          ).textTheme.titleMedium,
                                                                        ),
                                                                      ),
                                                                    );
                                                                  }).toList(),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  );
                                                },
                                              );

                                              overlay.insert(popupEntry);
                                            },
                                            child: InputDecorator(
                                              isEmpty: false,
                                              decoration: InputDecoration(
                                                labelText: 'GSTIN Available?',
                                                filled: true,
                                                fillColor: Colors.white,
                                                contentPadding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 10,
                                                    ),
                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(14),
                                                  borderSide: BorderSide(
                                                    color: Colors.grey.shade300,
                                                  ),
                                                ),
                                              ),
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      _gstAvailable,
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .titleMedium,
                                                    ),
                                                  ),
                                                  const Icon(
                                                    Icons.arrow_drop_down,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    if (_gstAvailable == 'Yes')
                                      _buildTextField(
                                        label: 'GSTIN',
                                        controller: _gstinController,
                                        validator: (value) {
                                          if (_gstAvailable == 'Yes' &&
                                              (value == null ||
                                                  value.trim().isEmpty)) {
                                            return 'GSTIN is required when available';
                                          }
                                          return null;
                                        },
                                      ),
                                    _buildTextField(
                                      label: 'Email',
                                      controller: _emailController,
                                      keyboardType: TextInputType.emailAddress,
                                    ),
                                    _buildTextField(
                                      label: 'Website',
                                      controller: _websiteController,
                                      keyboardType: TextInputType.url,
                                    ),
                                    const SizedBox(height: 4),
                                    if (_showCompanySaveSuccessMessage) ...[
                                      const Center(
                                        child: Text(
                                          'Company details saved successfully',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: kPrimaryBlue,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                    ],
                                    Row(
                                      children: [
                                        Expanded(
                                          child: FilledButton(
                                            onPressed: _saveCompanyDetails,
                                            style: FilledButton.styleFrom(
                                              backgroundColor: kPrimaryBlue,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 12,
                                                  ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                              ),
                                            ),
                                            child: const Text(
                                              'Save',
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: OutlinedButton(
                                            onPressed: _saveCompanyDetails,
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: kPrimaryBlue,
                                              side: const BorderSide(
                                                color: kPrimaryBlue,
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 12,
                                                  ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                              ),
                                            ),
                                            child: const Text(
                                              'Update',
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class PartiesPage extends StatefulWidget {
  const PartiesPage({super.key});

  @override
  State<PartiesPage> createState() => _PartiesPageState();
}

class _PartiesPageState extends State<PartiesPage> {
  final _partyNameController = TextEditingController();
  final _mobileNumberController = TextEditingController();
  final _alternateMobileController = TextEditingController();
  final _addressController = TextEditingController();
  final _gstinController = TextEditingController();
  final _openingBalanceController = TextEditingController();
  final _dueDateController = TextEditingController();
  final _alertBeforeDaysController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _accountHolderNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _ifscCodeController = TextEditingController();
  final _upiIdController = TextEditingController();
  final _upiMobileNumberController = TextEditingController();
  final List<Map<String, String>> _savedParties = [];

  String _partyType = 'Customer';
  String _category = 'Cement';
  String _gstinAvailable = 'No';
  String _balanceType = 'Zero';
  String _paymentTerms = 'Cash';
  String _qrScannerUploadData = '';
  String _partyMessage = '';
  int? _selectedPartyIndex;
  int _messageToken = 0;

  static const List<String> _categoryOptions = [
    'Cement',
    'Steel',
    'Sand & Aggregates',
    'Bricks & Blocks',
    'Tiles',
    'Granite & Marble',
    'Sanitary Ware',
    'Plumbing',
    'Electrical',
    'Paints',
    'Doors & Frames',
    'Windows & Glass',
    'Ceiling Materials',
    'Hardware',
    'Waterproofing Chemicals',
    'Wood & Plywood',
    'Interior Materials',
    'Gates & Railings',
    'Others',
  ];

  @override
  void initState() {
    super.initState();
    _loadParties();
  }

  @override
  void dispose() {
    _partyNameController.dispose();
    _mobileNumberController.dispose();
    _alternateMobileController.dispose();
    _addressController.dispose();
    _gstinController.dispose();
    _openingBalanceController.dispose();
    _dueDateController.dispose();
    _alertBeforeDaysController.dispose();
    _bankNameController.dispose();
    _accountHolderNameController.dispose();
    _accountNumberController.dispose();
    _ifscCodeController.dispose();
    _upiIdController.dispose();
    _upiMobileNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Parties',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Parties',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: kPrimaryBlue,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Customer and Supplier master',
                style: TextStyle(fontSize: 15, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              Card(
                color: kCardBlue,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _textField(
                            label: 'Party Name',
                            width: 320,
                            controller: _partyNameController,
                          ),
                          const SizedBox(width: 12),
                          _partyTypeDropdownField(),
                          const SizedBox(width: 12),
                          _textField(
                            label: 'Mobile Number',
                            width: 220,
                            controller: _mobileNumberController,
                          ),
                          const SizedBox(width: 12),
                          _textField(
                            label: 'Alternate Mobile',
                            width: 220,
                            controller: _alternateMobileController,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _textField(
                            label: 'Address',
                            width: 520,
                            controller: _addressController,
                          ),
                          const SizedBox(width: 12),
                          _categoryDropdownField(),
                          const SizedBox(width: 12),
                          _gstinAvailableDropdownField(),
                          const SizedBox(width: 12),
                          _textField(
                            label: 'GSTIN',
                            width: 260,
                            controller: _gstinController,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Balance / Due Details',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: kPrimaryBlue,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _textField(
                            label: 'Opening Balance',
                            width: 220,
                            controller: _openingBalanceController,
                          ),
                          const SizedBox(width: 12),
                          _balanceTypeDropdownField(),
                          const SizedBox(width: 12),
                          _paymentTermsDropdownField(),
                          const SizedBox(width: 12),
                          _textField(
                            label: 'Due Date',
                            width: 180,
                            controller: _dueDateController,
                          ),
                          const SizedBox(width: 12),
                          _textField(
                            label: 'Alert Before Days',
                            width: 180,
                            controller: _alertBeforeDaysController,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Supplier Payment Details',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: kPrimaryBlue,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _textField(
                            label: 'Bank Name',
                            width: 260,
                            controller: _bankNameController,
                          ),
                          const SizedBox(width: 12),
                          _textField(
                            label: 'Account Holder Name',
                            width: 300,
                            controller: _accountHolderNameController,
                          ),
                          const SizedBox(width: 12),
                          _textField(
                            label: 'Account Number',
                            width: 260,
                            controller: _accountNumberController,
                          ),
                          const SizedBox(width: 12),
                          _textField(
                            label: 'IFSC Code',
                            width: 180,
                            controller: _ifscCodeController,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _textField(
                            label: 'UPI ID',
                            width: 260,
                            controller: _upiIdController,
                          ),
                          const SizedBox(width: 12),
                          _textField(
                            label: 'UPI Mobile Number',
                            width: 220,
                            controller: _upiMobileNumberController,
                          ),
                          const SizedBox(width: 12),
                          _uploadPlaceholder(
                            label: _qrScannerUploadData.isEmpty
                                ? 'QR Scanner Upload'
                                : 'QR Uploaded',
                            width: 180,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          _actionButton(
                            label: 'Save Party',
                            width: 150,
                            onPressed: _saveParty,
                          ),
                          const SizedBox(width: 10),
                          _actionButton(
                            label: 'Update Party',
                            width: 150,
                            onPressed: _updateParty,
                          ),
                          const SizedBox(width: 10),
                          _actionButton(
                            label: 'Clear',
                            width: 120,
                            onPressed: _clearPartySelection,
                          ),
                        ],
                      ),
                      if (_partyMessage.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Center(
                          child: Text(
                            _partyMessage,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: kPrimaryBlue,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      const Text(
                        'Saved Parties',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: kPrimaryBlue,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        height: 42,
                        decoration: BoxDecoration(
                          color: kPrimaryBlue,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            _savedPartyHeaderCell('Party Name', width: 220),
                            _savedPartyHeaderCell('Type', width: 110),
                            _savedPartyHeaderCell('Category', width: 180),
                            _savedPartyHeaderCell('Mobile', width: 150),
                            _savedPartyHeaderCell('Balance', width: 130),
                            _savedPartyHeaderCell('Due Status', width: 140),
                            _savedPartyHeaderCell('Pay Now', width: 76),
                            _savedPartyHeaderCell('Edit', width: 58),
                            _savedPartyHeaderCell('Delete', width: 68),
                          ],
                        ),
                      ),
                      if (_savedParties.isEmpty)
                        const SizedBox(
                          height: 52,
                          child: Center(
                            child: Text(
                              'No parties saved yet',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ),
                        )
                      else
                        ..._savedParties.asMap().entries.map(
                          (entry) => _savedPartyRow(entry.key, entry.value),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _saveParty() {
    setState(() {
      _savedParties.add(_currentPartyData());
      _clearPartyForm();
      _selectedPartyIndex = null;
      _partyMessage = 'Party saved successfully';
    });
    _persistParties();
    _hidePartyMessageLater();
  }

  void _editParty(int index) {
    final party = _savedParties[index];
    setState(() {
      _partyNameController.text = party['partyName'] ?? '';
      _mobileNumberController.text = party['mobileNumber'] ?? '';
      _alternateMobileController.text = party['alternateMobile'] ?? '';
      _addressController.text = party['address'] ?? '';
      _gstinController.text = party['gstin'] ?? '';
      _openingBalanceController.text = party['openingBalance'] ?? '';
      _dueDateController.text = party['dueDate'] ?? '';
      _alertBeforeDaysController.text = party['alertBeforeDays'] ?? '';
      _bankNameController.text = party['bankName'] ?? '';
      _accountHolderNameController.text = party['accountHolderName'] ?? '';
      _accountNumberController.text = party['accountNumber'] ?? '';
      _ifscCodeController.text = party['ifscCode'] ?? '';
      _upiIdController.text = party['upiId'] ?? '';
      _upiMobileNumberController.text = party['upiMobileNumber'] ?? '';
      _qrScannerUploadData = party['qrScannerUpload'] ?? '';
      _partyType = party['partyType'] ?? 'Customer';
      _category = party['category'] ?? 'Cement';
      _gstinAvailable = party['gstinAvailable'] ?? 'No';
      _balanceType = party['balanceType'] ?? 'Zero';
      _paymentTerms = party['paymentTerms'] ?? 'Cash';
      _selectedPartyIndex = index;
    });
  }

  void _updateParty() {
    final selectedIndex = _selectedPartyIndex;
    if (selectedIndex == null ||
        selectedIndex < 0 ||
        selectedIndex >= _savedParties.length)
      return;

    setState(() {
      _savedParties[selectedIndex] = _currentPartyData();
      _clearPartyForm();
      _selectedPartyIndex = null;
      _partyMessage = 'Party updated successfully';
    });
    _persistParties();
    _hidePartyMessageLater();
  }

  void _deleteParty(int index) {
    setState(() {
      _savedParties.removeAt(index);
      if (_selectedPartyIndex == index) {
        _clearPartyForm();
        _selectedPartyIndex = null;
      } else if (_selectedPartyIndex != null && _selectedPartyIndex! > index) {
        _selectedPartyIndex = _selectedPartyIndex! - 1;
      }
      _partyMessage = 'Party deleted successfully';
    });
    _persistParties();
    _hidePartyMessageLater();
  }

  Future<void> _loadParties() async {
    final prefs = await SharedPreferences.getInstance();
    final savedParties = prefs.getString('parties_list');
    if (savedParties == null || savedParties.isEmpty) return;

    final dynamic decodedParties;
    try {
      decodedParties = jsonDecode(savedParties);
    } catch (_) {
      return;
    }
    if (decodedParties is! List) return;

    final parties = decodedParties
        .whereType<Map>()
        .map(
          (party) => party.map(
            (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
          ),
        )
        .toList();

    if (!mounted) return;
    setState(() {
      _savedParties
        ..clear()
        ..addAll(parties);
    });
  }

  Future<void> _persistParties() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('parties_list', jsonEncode(_savedParties));
  }

  Map<String, String> _currentPartyData() {
    return {
      'partyName': _partyNameController.text,
      'partyType': _partyType,
      'mobileNumber': _mobileNumberController.text,
      'alternateMobile': _alternateMobileController.text,
      'address': _addressController.text,
      'category': _category,
      'gstinAvailable': _gstinAvailable,
      'gstin': _gstinController.text,
      'openingBalance': _openingBalanceController.text,
      'balanceType': _balanceType,
      'paymentTerms': _paymentTerms,
      'dueDate': _dueDateController.text,
      'alertBeforeDays': _alertBeforeDaysController.text,
      'bankName': _bankNameController.text,
      'accountHolderName': _accountHolderNameController.text,
      'accountNumber': _accountNumberController.text,
      'ifscCode': _ifscCodeController.text,
      'upiId': _upiIdController.text,
      'upiMobileNumber': _upiMobileNumberController.text,
      'qrScannerUpload': _qrScannerUploadData,
    };
  }

  void _clearPartyForm() {
    _partyNameController.clear();
    _mobileNumberController.clear();
    _alternateMobileController.clear();
    _addressController.clear();
    _gstinController.clear();
    _openingBalanceController.clear();
    _dueDateController.clear();
    _alertBeforeDaysController.clear();
    _bankNameController.clear();
    _accountHolderNameController.clear();
    _accountNumberController.clear();
    _ifscCodeController.clear();
    _upiIdController.clear();
    _upiMobileNumberController.clear();
    _qrScannerUploadData = '';
    _partyType = 'Customer';
    _category = 'Cement';
    _gstinAvailable = 'No';
    _balanceType = 'Zero';
    _paymentTerms = 'Cash';
  }

  void _clearPartySelection() {
    setState(() {
      _clearPartyForm();
      _selectedPartyIndex = null;
    });
  }

  void _hidePartyMessageLater() {
    final token = ++_messageToken;
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted || token != _messageToken) return;
      setState(() => _partyMessage = '');
    });
  }

  void _showPayNowDialog(Map<String, String> party) {
    var paymentMethod = 'QR Payment';
    var myBank = 'SBI';
    var otherBankName = '';
    var payNowMessage = '';
    var payNowMessageToken = 0;
    var isPayNowDialogOpen = true;

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final screenHeight = MediaQuery.of(dialogContext).size.height;
        final maxDialogHeight = screenHeight * 0.85;

        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 520,
              maxHeight: maxDialogHeight,
            ),
            child: StatefulBuilder(
              builder: (context, setDialogState) {
                return SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Pay Now',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: kPrimaryBlue,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _payNowValue(party['partyName']),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF475467),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Party Details',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: kPrimaryBlue,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _payNowDetails(party),
                        const SizedBox(height: 18),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final fieldWidth = constraints.maxWidth >= 470
                                ? (constraints.maxWidth - 10) / 2
                                : constraints.maxWidth;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: [
                                    _payNowDropdown(
                                      label: 'Payment Method',
                                      width: fieldWidth,
                                      value: paymentMethod,
                                      options: const [
                                        'QR Payment',
                                        'UPI App',
                                        'Mobile Banking',
                                        'Net Banking',
                                      ],
                                      onChanged: (value) => setDialogState(
                                        () => paymentMethod = value,
                                      ),
                                    ),
                                    _payNowDropdown(
                                      label: 'My Bank',
                                      width: fieldWidth,
                                      value: myBank,
                                      options: const [
                                        'SBI',
                                        'HDFC Bank',
                                        'ICICI Bank',
                                        'Axis Bank',
                                        'Kotak Mahindra Bank',
                                        'Canara Bank',
                                        'Bank of Baroda',
                                        'Punjab National Bank',
                                        'PNB',
                                        'Union Bank of India',
                                        'Indian Bank',
                                        'Bank of India',
                                        'Central Bank of India',
                                        'Indian Overseas Bank',
                                        'Yes Bank',
                                        'IDFC FIRST Bank',
                                        'IndusInd Bank',
                                        'Federal Bank',
                                        'South Indian Bank',
                                        'Karnataka Bank',
                                        'Karur Vysya Bank',
                                        'City Union Bank',
                                        'AU Small Finance Bank',
                                        'Bandhan Bank',
                                        'RBL Bank',
                                        'DBS Bank',
                                        'Other',
                                      ],
                                      onChanged: (value) =>
                                          setDialogState(() => myBank = value),
                                    ),
                                  ],
                                ),
                                if (myBank == 'Other') ...[
                                  const SizedBox(height: 10),
                                  Align(
                                    alignment: constraints.maxWidth >= 470
                                        ? Alignment.centerRight
                                        : Alignment.centerLeft,
                                    child: SizedBox(
                                      width: fieldWidth,
                                      height: 52,
                                      child: TextFormField(
                                        initialValue: otherBankName,
                                        onChanged: (value) =>
                                            otherBankName = value,
                                        decoration: InputDecoration(
                                          labelText: 'Enter Bank Name',
                                          filled: true,
                                          fillColor: Colors.white,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 12,
                                              ),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 18),
                        if (payNowMessage.isNotEmpty) ...[
                          Center(
                            child: Text(
                              payNowMessage,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFDC2626),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            SizedBox(
                              height: 48,
                              child: OutlinedButton(
                                onPressed: () =>
                                    Navigator.of(dialogContext).pop(),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: kPrimaryBlue,
                                  side: const BorderSide(color: kPrimaryBlue),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text('Close'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              height: 48,
                              child: ElevatedButton(
                                onPressed: () => _continuePayNow(
                                  party: party,
                                  paymentMethod: paymentMethod,
                                  myBank: myBank,
                                  otherBankName: otherBankName,
                                  showMessage: (message) {
                                    final token = ++payNowMessageToken;
                                    setDialogState(
                                      () => payNowMessage = message,
                                    );
                                    Future.delayed(
                                      const Duration(seconds: 2),
                                      () {
                                        if (!mounted ||
                                            !isPayNowDialogOpen ||
                                            token != payNowMessageToken)
                                          return;
                                        setDialogState(
                                          () => payNowMessage = '',
                                        );
                                      },
                                    );
                                  },
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: kPrimaryBlue,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                child: const Text('Continue / Open Payment'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    ).whenComplete(() => isPayNowDialogOpen = false);
  }

  void _continuePayNow({
    required Map<String, String> party,
    required String paymentMethod,
    required String myBank,
    required String otherBankName,
    required ValueChanged<String> showMessage,
  }) {
    if (paymentMethod == 'QR Payment') {
      showMessage('Scan QR using any UPI app');
      return;
    }

    if (myBank == 'Other') {
      final typedBankName = otherBankName.trim();
      if (typedBankName.isEmpty) {
        showMessage('Please enter bank name');
        return;
      }

      final query = Uri.encodeComponent('$typedBankName official net banking');
      _openPayNowLink('https://www.google.com/search?q=$query');
      return;
    }

    const bankUrls = {
      'SBI': 'https://retail.onlinesbi.sbi',
      'HDFC Bank': 'https://netbanking.hdfcbank.com/netbanking/',
      'ICICI Bank': 'https://retailnetbanking.icici.bank.in/',
      'Axis Bank': 'https://www.axis.bank.in/bank-smart/internet-banking',
      'Kotak Mahindra Bank': 'https://netbanking.kotak.com',
      'Canara Bank': 'https://canarabank.com',
      'Bank of Baroda': 'https://bobibanking.com',
      'Punjab National Bank': 'https://ibanking.pnb.bank.in',
      'PNB': 'https://ibanking.pnb.bank.in',
      'Union Bank of India': 'https://www.unionbankonline.co.in',
      'Indian Bank': 'https://www.netbanking.indianbank.in',
      'Bank of India': 'https://bankofindia.co.in',
      'Central Bank of India': 'https://www.centralbankofindia.co.in',
      'Indian Overseas Bank': 'https://www.iob.in',
      'Yes Bank': 'https://www.yesbank.in',
      'IDFC FIRST Bank': 'https://www.idfcfirstbank.com',
      'IndusInd Bank': 'https://www.indusind.com',
      'Federal Bank': 'https://www.federalbank.co.in',
      'South Indian Bank': 'https://www.southindianbank.com',
      'Karnataka Bank': 'https://karnatakabank.com',
      'Karur Vysya Bank': 'https://www.kvb.co.in',
      'City Union Bank': 'https://www.cityunionbank.com',
      'AU Small Finance Bank': 'https://www.aubank.in',
      'Bandhan Bank': 'https://bandhanbank.com',
      'RBL Bank': 'https://www.rblbank.com',
      'DBS Bank': 'https://www.dbs.com/in',
    };
    final bankUrl = bankUrls[myBank];
    if (bankUrl == null) {
      showMessage('Please open your bank website manually');
      return;
    }

    _openPayNowLink(bankUrl);
  }

  void _openPayNowLink(String url) {
    html.window.open(url, '_blank');
  }

  Widget _payNowDetails(Map<String, String> party) {
    final details = [
      {'label': 'Balance', 'value': _payNowValue(party['openingBalance'])},
      {'label': 'Due Status', 'value': _payNowValue(party['balanceType'])},
      {'label': 'Bank Name', 'value': _payNowValue(party['bankName'])},
      {
        'label': 'Account Holder Name',
        'value': _payNowValue(party['accountHolderName']),
      },
      {
        'label': 'Account Number',
        'value': _payNowValue(party['accountNumber']),
      },
      {'label': 'IFSC Code', 'value': _payNowValue(party['ifscCode'])},
      {'label': 'UPI ID', 'value': _payNowValue(party['upiId'])},
      {
        'label': 'UPI Mobile Number',
        'value': _payNowValue(party['upiMobileNumber']),
      },
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final tileWidth = constraints.maxWidth >= 470
            ? (constraints.maxWidth - 10) / 2
            : constraints.maxWidth;

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _payNowDetailTile(
              label: 'Party Name',
              value: _payNowValue(party['partyName']),
              width: constraints.maxWidth,
            ),
            for (final detail in details)
              _payNowDetailTile(
                label: detail['label'] ?? '',
                value: detail['value'] ?? '-',
                width: tileWidth,
              ),
            _payNowQrTile(
              qrImageData: party['qrScannerUpload'] ?? '',
              width: constraints.maxWidth,
            ),
          ],
        );
      },
    );
  }

  Widget _payNowQrTile({required String qrImageData, required double width}) {
    final trimmedQrImageData = qrImageData.trim();

    return SizedBox(
      width: width,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'QR Scanner',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 8),
              if (trimmedQrImageData.isEmpty)
                const Text(
                  'QR not uploaded',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                )
              else
                Center(
                  child: _payNowQrCard(
                    qrImageData: trimmedQrImageData,
                    size: 300,
                    onTap: () => _showPayNowQrPreview(trimmedQrImageData),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _payNowQrCard({
    required String qrImageData,
    required double size,
    VoidCallback? onTap,
  }) {
    final qrBytes = base64Decode(
      qrImageData.contains(',') ? qrImageData.split(',').last : qrImageData,
    );

    final card = DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Scan QR',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: kPrimaryBlue,
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.memory(
                qrBytes,
                width: size,
                height: size,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const SizedBox(
                    width: 210,
                    height: 48,
                    child: Center(
                      child: Text(
                        'QR not uploaded',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );

    if (onTap == null) return card;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: card,
    );
  }

  void _showPayNowQrPreview(String qrImageData) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _payNowQrCard(qrImageData: qrImageData, size: 320),
                const SizedBox(height: 18),
                SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kPrimaryBlue,
                      side: const BorderSide(color: kPrimaryBlue),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _payNowDetailTile({
    required String label,
    required String value,
    required double width,
  }) {
    return SizedBox(
      width: width,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _payNowDropdown({
    required String label,
    required double width,
    required String value,
    required List<String> options,
    required ValueChanged<String> onChanged,
  }) {
    return SizedBox(
      width: width,
      height: 52,
      child: DropdownButtonFormField<String>(
        key: ValueKey('pay-now-$label-$value'),
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
        items: options
            .map(
              (option) => DropdownMenuItem(value: option, child: Text(option)),
            )
            .toList(),
        onChanged: (value) {
          if (value == null) return;
          onChanged(value);
        },
      ),
    );
  }

  String _payNowValue(String? value) {
    final trimmedValue = value?.trim() ?? '';
    return trimmedValue.isEmpty ? '-' : trimmedValue;
  }

  Widget _actionButton({
    required String label,
    required double width,
    VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: width,
      height: 46,
      child: ElevatedButton(
        onPressed: onPressed ?? () {},
        style: ElevatedButton.styleFrom(
          backgroundColor: kPrimaryBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        child: Text(label),
      ),
    );
  }

  Widget _savedPartyRow(int index, Map<String, String> party) {
    return SizedBox(
      height: 42,
      child: Row(
        children: [
          _savedPartyCell(party['partyName'] ?? '', width: 220),
          _savedPartyCell(party['partyType'] ?? '', width: 110),
          _savedPartyCell(party['category'] ?? '', width: 180),
          _savedPartyCell(party['mobileNumber'] ?? '', width: 150),
          _savedPartyCell(party['openingBalance'] ?? '', width: 130),
          _savedPartyCell(party['balanceType'] ?? '', width: 140),
          _savedPartyActionButton(
            label: 'Pay Now',
            width: 76,
            color: const Color(0xFF16A34A),
            onPressed: () => _showPayNowDialog(party),
          ),
          _savedPartyActionButton(
            label: 'Edit',
            width: 58,
            color: kPrimaryBlue,
            onPressed: () => _editParty(index),
          ),
          _savedPartyActionButton(
            label: 'Delete',
            width: 68,
            color: const Color(0xFFDC2626),
            onPressed: () => _deleteParty(index),
          ),
        ],
      ),
    );
  }

  Widget _savedPartyCell(String value, {required double width}) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(
          value,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, color: Color(0xFF475467)),
        ),
      ),
    );
  }

  Widget _savedPartyActionButton({
    required String label,
    required double width,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: width,
      height: 42,
      child: Center(
        child: SizedBox(
          width: width,
          height: 30,
          child: ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              textStyle: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: Text(label),
          ),
        ),
      ),
    );
  }

  Widget _savedPartyHeaderCell(String label, {required double width}) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _uploadPlaceholder({required String label, required double width}) {
    return SizedBox(
      width: width,
      height: 52,
      child: OutlinedButton(
        onPressed: _pickQrScannerUpload,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF475467),
          side: const BorderSide(color: Color(0xFF64748B)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(label, textAlign: TextAlign.center),
      ),
    );
  }

  void _pickQrScannerUpload() {
    final uploadInput = html.FileUploadInputElement()..accept = 'image/*';
    uploadInput.click();
    uploadInput.onChange.first.then((_) {
      final files = uploadInput.files;
      if (files == null || files.isEmpty) return;

      final reader = html.FileReader();
      reader.onLoadEnd.first.then((_) {
        final result = reader.result;
        if (!mounted || result is! String) return;
        setState(() => _qrScannerUploadData = result);
      });
      reader.readAsDataUrl(files.first);
    });
  }

  Widget _textField({
    required String label,
    required double width,
    TextEditingController? controller,
  }) {
    return SizedBox(
      width: width,
      height: 52,
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  Widget _partyTypeDropdownField() {
    final GlobalKey partyTypeKey = GlobalKey();

    return SizedBox(
      key: partyTypeKey,
      width: 180,
      height: 52,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          final RenderBox button =
              partyTypeKey.currentContext!.findRenderObject() as RenderBox;
          final OverlayState overlay = Overlay.of(context);
          final RenderBox overlayBox =
              overlay.context.findRenderObject() as RenderBox;

          final Offset position =
              button.localToGlobal(Offset.zero, ancestor: overlayBox);

          late OverlayEntry popupEntry;
          popupEntry = OverlayEntry(
            builder: (context) {
              return Stack(
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: popupEntry.remove,
                      child: Container(color: Colors.transparent),
                    ),
                  ),
                  Positioned(
                    left: position.dx,
                    top: position.dy + button.size.height,
                    width: button.size.width,
                    child: Material(
                      color: Colors.transparent,
                      child: Container(
                        width: button.size.width,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: ['Customer', 'Supplier', 'Both'].map((
                            partyType,
                          ) {
                            return GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                popupEntry.remove();
                                setState(() {
                                  _partyType = partyType;
                                });
                              },
                              child: Container(
                                width: button.size.width,
                                height: 44,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  partyType,
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );

          overlay.insert(popupEntry);
        },
        child: InputDecorator(
          isEmpty: false,
          decoration: InputDecoration(
            labelText: 'Party Type',
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _partyType,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const Icon(Icons.arrow_drop_down),
            ],
          ),
        ),
      ),
    );
  }

  Widget _categoryDropdownField() {
    final GlobalKey categoryKey = GlobalKey();

    return SizedBox(
      key: categoryKey,
      width: 260,
      height: 52,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          final RenderBox button =
              categoryKey.currentContext!.findRenderObject() as RenderBox;
          final OverlayState overlay = Overlay.of(context);
          final RenderBox overlayBox =
              overlay.context.findRenderObject() as RenderBox;

          final Offset position =
              button.localToGlobal(Offset.zero, ancestor: overlayBox);
          final double popupTop = position.dy + button.size.height;
          final double popupMaxHeight = overlayBox.size.height - popupTop;

          late OverlayEntry popupEntry;
          popupEntry = OverlayEntry(
            builder: (context) {
              return Stack(
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: popupEntry.remove,
                      child: Container(color: Colors.transparent),
                    ),
                  ),
                  Positioned(
                    left: position.dx,
                    top: popupTop,
                    width: button.size.width,
                    child: Material(
                      color: Colors.transparent,
                      child: Container(
                        width: button.size.width,
                        constraints: BoxConstraints(maxHeight: popupMaxHeight),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: ListView(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          children: _categoryOptions.map((category) {
                            return GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                popupEntry.remove();
                                setState(() {
                                  _category = category;
                                });
                              },
                              child: Container(
                                width: button.size.width,
                                height: 44,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  category,
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );

          overlay.insert(popupEntry);
        },
        child: InputDecorator(
          isEmpty: false,
          decoration: InputDecoration(
            labelText: 'Category',
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _category,
                  style: Theme.of(context).textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.arrow_drop_down),
            ],
          ),
        ),
      ),
    );
  }

  Widget _gstinAvailableDropdownField() {
    final GlobalKey gstinAvailableKey = GlobalKey();

    return SizedBox(
      key: gstinAvailableKey,
      width: 160,
      height: 52,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          final RenderBox button =
              gstinAvailableKey.currentContext!.findRenderObject() as RenderBox;
          final OverlayState overlay = Overlay.of(context);
          final RenderBox overlayBox =
              overlay.context.findRenderObject() as RenderBox;

          final Offset position =
              button.localToGlobal(Offset.zero, ancestor: overlayBox);

          late OverlayEntry popupEntry;
          popupEntry = OverlayEntry(
            builder: (context) {
              return Stack(
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: popupEntry.remove,
                      child: Container(color: Colors.transparent),
                    ),
                  ),
                  Positioned(
                    left: position.dx,
                    top: position.dy + button.size.height,
                    width: button.size.width,
                    child: Material(
                      color: Colors.transparent,
                      child: Container(
                        width: button.size.width,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: ['Yes', 'No'].map((gstinAvailable) {
                            return GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                popupEntry.remove();
                                setState(() {
                                  _gstinAvailable = gstinAvailable;
                                });
                              },
                              child: Container(
                                width: button.size.width,
                                height: 44,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 0,
                                ),
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  gstinAvailable,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontSize: 18),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );

          overlay.insert(popupEntry);
        },
        child: InputDecorator(
          isEmpty: false,
          decoration: InputDecoration(
            labelText: 'GSTIN Available',
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _gstinAvailable,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const Icon(Icons.arrow_drop_down),
            ],
          ),
        ),
      ),
    );
  }

  Widget _balanceTypeDropdownField() {
    final GlobalKey balanceTypeKey = GlobalKey();

    return SizedBox(
      key: balanceTypeKey,
      width: 200,
      height: 52,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          final RenderBox button =
              balanceTypeKey.currentContext!.findRenderObject() as RenderBox;
          final OverlayState overlay = Overlay.of(context);
          final RenderBox overlayBox =
              overlay.context.findRenderObject() as RenderBox;

          final Offset position =
              button.localToGlobal(Offset.zero, ancestor: overlayBox);

          late OverlayEntry popupEntry;
          popupEntry = OverlayEntry(
            builder: (context) {
              return Stack(
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: popupEntry.remove,
                      child: Container(color: Colors.transparent),
                    ),
                  ),
                  Positioned(
                    left: position.dx,
                    top: position.dy + button.size.height,
                    width: button.size.width,
                    child: Material(
                      color: Colors.transparent,
                      child: Container(
                        width: button.size.width,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: ['Receivable', 'Payable', 'Zero'].map((
                            balanceType,
                          ) {
                            return GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                popupEntry.remove();
                                setState(() {
                                  _balanceType = balanceType;
                                });
                              },
                              child: Container(
                                width: button.size.width,
                                height: 44,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  balanceType,
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );

          overlay.insert(popupEntry);
        },
        child: InputDecorator(
          isEmpty: false,
          decoration: InputDecoration(
            labelText: 'Balance Type',
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _balanceType,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const Icon(Icons.arrow_drop_down),
            ],
          ),
        ),
      ),
    );
  }

  Widget _paymentTermsDropdownField() {
    final GlobalKey paymentTermsKey = GlobalKey();

    return SizedBox(
      key: paymentTermsKey,
      width: 180,
      height: 52,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          final RenderBox button =
              paymentTermsKey.currentContext!.findRenderObject() as RenderBox;
          final OverlayState overlay = Overlay.of(context);
          final RenderBox overlayBox =
              overlay.context.findRenderObject() as RenderBox;

          final Offset position =
              button.localToGlobal(Offset.zero, ancestor: overlayBox);

          late OverlayEntry popupEntry;
          popupEntry = OverlayEntry(
            builder: (context) {
              return Stack(
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: popupEntry.remove,
                      child: Container(color: Colors.transparent),
                    ),
                  ),
                  Positioned(
                    left: position.dx,
                    top: position.dy + button.size.height,
                    width: button.size.width,
                    child: Material(
                      color: Colors.transparent,
                      child: Container(
                        width: button.size.width,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: ['Cash', '7 Days', '15 Days', '30 Days'].map((
                            paymentTerms,
                          ) {
                            return GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                popupEntry.remove();
                                setState(() {
                                  _paymentTerms = paymentTerms;
                                });
                              },
                              child: Container(
                                width: button.size.width,
                                height: 44,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  paymentTerms,
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );

          overlay.insert(popupEntry);
        },
        child: InputDecorator(
          isEmpty: false,
          decoration: InputDecoration(
            labelText: 'Payment Terms',
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _paymentTerms,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const Icon(Icons.arrow_drop_down),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dropdownField({
    required String label,
    required double width,
    required String value,
    required List<String> options,
    required ValueChanged<String> onChanged,
  }) {
    return SizedBox(
      width: width,
      height: 52,
      child: DropdownButtonFormField<String>(
        key: ValueKey('$label-$value'),
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
        items: options
            .map(
              (option) => DropdownMenuItem(value: option, child: Text(option)),
            )
            .toList(),
        onChanged: (value) {
          if (value == null) return;
          onChanged(value);
        },
      ),
    );
  }
}

class SectionPage extends StatelessWidget {
  final String title;

  const SectionPage({required this.title, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.dashboard_customize,
                size: 78,
                color: kPrimaryBlue.withAlpha(230),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: kPrimaryBlue,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'This section is ready for module content. Build your company workflows, inventory entries, invoices, and reports from here.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Color(0xFF475467)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  final _searchController = TextEditingController();
  final List<ProductMaster> _products = [];
  final List<ProductMaster> _filteredProducts = [];
  final List<PurchaseStockLot> _stockLots = [];
  final List<PurchaseStockLot> _filteredStockLots = [];
  @override
  void initState() {
    super.initState();
    _loadProducts();
    _searchController.addListener(() => _updateSearch(_searchController.text));
  }

  Future<void> _loadProducts() async {
    final prefs = await SharedPreferences.getInstance();

    final savedProducts = prefs.getStringList('product_master_list') ?? [];
    final productMap = <String, ProductMaster>{};

    for (final entry in savedProducts) {
      final product = ProductMaster.fromJson(
        jsonDecode(entry) as Map<String, dynamic>,
      );
      final key = product.productCode.trim().toLowerCase();
      if (key.isEmpty) continue;
      productMap[key] = product;
    }

    final savedLots = prefs.getStringList('purchase_stock_lot_list') ?? [];
    final lots = savedLots
        .map(
          (s) =>
              PurchaseStockLot.fromJson(jsonDecode(s) as Map<String, dynamic>),
        )
        .where((lot) => lot.productCode.trim().isNotEmpty)
        .toList();

    setState(() {
      _products
        ..clear()
        ..addAll(productMap.values);

      _filteredProducts
        ..clear()
        ..addAll(_products);

      _stockLots
        ..clear()
        ..addAll(lots);

      _filteredStockLots
        ..clear()
        ..addAll(_stockLots);
    });

    debugPrint('InventoryPage loaded products: ${_products.length}');
    debugPrint('InventoryPage loaded stock lots: ${_stockLots.length}');
  }

  void _updateSearch(String query) {
    final text = query.trim().toLowerCase();
    setState(() {
      if (text.isEmpty) {
        _filteredProducts
          ..clear()
          ..addAll(_products);
        return;
      }
      _filteredProducts
        ..clear()
        ..addAll(
          _products.where((product) {
            final code = product.productCode.toLowerCase();
            final name = product.productName.toLowerCase();
            final unit = product.unit.toLowerCase();
            return code.contains(text) ||
                name.contains(text) ||
                unit.contains(text);
          }),
        );
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inventoryProductCodes = _products
        .map((product) => product.productCode)
        .join(', ');
    debugPrint(
      'InventoryPage build displaying ${_products.length} products: [$inventoryProductCodes]',
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Inventory')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                color: kLightBlue,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Search by product code, name or unit',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      suffixIcon: _searchController.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                              },
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _filteredStockLots.isEmpty
                    ? const Center(
                        child: Text(
                          'No purchase stock lots found.',
                          style: TextStyle(fontSize: 14, color: Colors.black54),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredStockLots.length,
                        itemBuilder: (context, index) {
                          final lot = _filteredStockLots[index];

                          return Container(
                            height: 58,
                            margin: const EdgeInsets.only(bottom: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: kCardBlue,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    '${lot.lotNo} - ${lot.productName}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.left,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: kPrimaryBlue,
                                    ),
                                  ),
                                ),
                                _inventoryInfo('Purchase No', lot.purchaseNo),
                                _inventoryInfo('Date', lot.purchaseDate),
                                _inventoryInfo('Unit', lot.unit),
                                _inventoryInfo(
                                  'Qty',
                                  lot.remainingQty.toString(),
                                ),
                                _inventoryInfo(
                                  'Remaining',
                                  lot.remainingQty.toString(),
                                ),
                                _inventoryInfo(
                                  'Purchase Rate',
                                  '₹${lot.purchaseRate.toStringAsFixed(2)}',
                                ),
                                _inventoryInfo(
                                  'Total Value',
                                  '₹${(lot.remainingQty * lot.purchaseRate).toStringAsFixed(2)}',
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _inventoryInfo(String label, String value) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 9, color: Colors.black54),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: kPrimaryBlue,
            ),
          ),
        ],
      ),
    );
  }
}

class ProductMasterPage extends StatefulWidget {
  const ProductMasterPage({super.key});

  @override
  State<ProductMasterPage> createState() => _ProductMasterPageState();
}

class _ProductMasterPageState extends State<ProductMasterPage> {
  final _formKey = GlobalKey<FormState>();
  final _productCodeController = TextEditingController();
  final _productNameController = TextEditingController();
  final _purchasePriceController = TextEditingController();
  final _mrpPriceController = TextEditingController();
  final _defaultSalePriceController = TextEditingController();
  final _minimumStockAlertController = TextEditingController();
  final _currentStockController = TextEditingController();

  String _selectedCategory = 'Tiles';
  String _selectedUnit = 'Nos';
  final List<ProductMaster> _products = [];
  int? _editingIndex;
  bool _isDuplicateCode = false;

  static const List<String> _categoryOptions = [
    'Tiles',
    'Granite',
    'Sanitary',
    'Plumbing',
    'Electrical',
    'Paints',
    'Doors',
    'Windows',
    'Ceiling',
    'Hardware',
    'Building Materials',
    'Other',
  ];

  static const List<String> _unitOptions = [
    'Nos',
    'Box',
    'Bag',
    'Kg',
    'Liter',
    'Feet',
    'Meter',
    'Sq.ft',
    'Sq.meter',
  ];

  bool get _isEditing => _editingIndex != null;

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _productCodeController.addListener(_checkDuplicateCode);
  }

  Future<void> _loadProducts() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('product_master_list') ?? [];
    final productMap = <String, ProductMaster>{};

    for (final entry in saved) {
      try {
        final product = ProductMaster.fromJson(
          jsonDecode(entry) as Map<String, dynamic>,
        );
        final key = product.productCode.trim().toLowerCase();
        if (key.isNotEmpty) {
          productMap[key] = product;
        }
      } catch (_) {}
    }

    final products = productMap.values.toList()
      ..sort((a, b) => a.productCode.compareTo(b.productCode));

    if (!mounted) return;

    setState(() {
      _products
        ..clear()
        ..addAll(products);
    });
  }

  Future<void> _loadForEditByCode(String productCode) async {
    if (_products.isEmpty) {
      await _loadProducts();
    }
    final index = _products.indexWhere(
      (product) =>
          product.productCode.trim().toLowerCase() ==
          productCode.trim().toLowerCase(),
    );
    if (index != -1) {
      _loadForEdit(index);
    }
  }

  Future<void> _confirmDeleteProductByCode(String productCode) async {
    if (_products.isEmpty) {
      await _loadProducts();
    }
    final index = _products.indexWhere(
      (product) =>
          product.productCode.trim().toLowerCase() ==
          productCode.trim().toLowerCase(),
    );
    if (index != -1) {
      await _confirmDeleteProduct(index);
    }
  }

  void _checkDuplicateCode() {
    final v = _productCodeController.text.trim();
    if (v.isEmpty) {
      if (_isDuplicateCode) setState(() => _isDuplicateCode = false);
      return;
    }
    final enteredLower = v.toLowerCase();
    final existingIndex = _products.indexWhere(
      (p) => p.productCode.trim().toLowerCase() == enteredLower,
    );
    final isDup = _editingIndex == null
        ? existingIndex != -1
        : (existingIndex != -1 && existingIndex != _editingIndex);
    if (isDup != _isDuplicateCode) {
      setState(() {
        _isDuplicateCode = isDup;
      });
    }
  }

  Future<void> _persistProducts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'product_master_list',
      _products.map((product) => jsonEncode(product.toJson())).toList(),
    );
  }

  void _clearForm() {
    _formKey.currentState?.reset();
    // Clear product code for manual entry
    _productCodeController.clear();
    _productNameController.clear();
    _purchasePriceController.clear();
    _mrpPriceController.clear();
    _defaultSalePriceController.clear();
    _minimumStockAlertController.clear();
    _currentStockController.clear();
    _selectedCategory = 'Tiles';
    _selectedUnit = 'Nos';
    setState(() {
      _editingIndex = null;
    });
  }

  void _loadForEdit(int index) {
    final product = _products[index];
    _editingIndex = index;
    _productCodeController.text = product.productCode;
    _productNameController.text = product.productName;
    _selectedCategory = product.category;
    _selectedUnit = product.unit;
    _purchasePriceController.text = product.purchasePrice.toStringAsFixed(2);
    _mrpPriceController.text = product.mrpPrice.toStringAsFixed(2);
    _defaultSalePriceController.text = product.defaultSalePrice.toStringAsFixed(
      2,
    );
    _minimumStockAlertController.text = product.minimumStockAlert.toString();
    _currentStockController.text = product.currentStock.toString();
    setState(() {});
  }

  Future<void> _saveProduct() async {
    final enteredCode = _productCodeController.text.trim();
    final enteredLower = enteredCode.toLowerCase();

    final duplicateExists = _products.any(
      (p) => p.productCode.trim().toLowerCase() == enteredLower,
    );

    if (_editingIndex == null && duplicateExists) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product code already exists')),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final newProduct = ProductMaster(
      productCode: enteredCode,
      productName: _productNameController.text.trim(),
      category: _selectedCategory,
      unit: _selectedUnit,
      purchasePrice: double.tryParse(_purchasePriceController.text.trim()) ?? 0,
      mrpPrice: double.tryParse(_mrpPriceController.text.trim()) ?? 0,
      defaultSalePrice:
          double.tryParse(_defaultSalePriceController.text.trim()) ?? 0,
      minimumStockAlert:
          int.tryParse(_minimumStockAlertController.text.trim()) ?? 0,
      currentStock: 0,
    );

    final editingIndex = _editingIndex;
    final existingIndex = _products.indexWhere(
      (item) => item.productCode.trim().toLowerCase() == enteredLower,
    );

    if (editingIndex != null &&
        existingIndex != -1 &&
        existingIndex != editingIndex) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Product code already exists'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (editingIndex != null) {
      setState(() {
        _products[editingIndex] = newProduct;
      });
      await _persistProducts();
      await _loadProducts();
      debugPrint(
        'ProductMasterPage after save (update) saved ${_products.length} products: ${_products.map((p) => p.productCode).join(", ")}',
      );
      if (!mounted) return;
      _clearForm();
      final overlay = Overlay.of(context);
      late OverlayEntry entry;

      entry = OverlayEntry(
        builder: (context) => Positioned(
          bottom: 20,
          left: 0,
          right: 0,

          child: Material(
            color: Colors.transparent,
            child: Center(
              child: const Text(
                'Product Updated',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: kPrimaryBlue,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      );

      overlay.insert(entry);

      Future.delayed(const Duration(seconds: 2), () {
        if (entry.mounted) entry.remove();
      });
      return;
    }

    setState(() {
      _products.add(newProduct);
    });
    await _persistProducts();
    await _loadProducts();
    debugPrint(
      'ProductMasterPage after save (create) saved ${_products.length} products: ${_products.map((p) => p.productCode).join(", ")}',
    );
    if (!mounted) return;
    _clearForm();
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => Positioned(
        bottom: 20,
        left: 0,
        right: 0,
        child: Material(
          color: Colors.transparent,
          child: Center(
            child: const Text(
              'Product Saved',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: kPrimaryBlue,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);

    Future.delayed(const Duration(seconds: 2), () {
      if (entry.mounted) entry.remove();
    });
  }

  Future<void> _confirmDelete() async {
    if (!_isEditing) return;
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete product'),
          content: const Text('Are you sure you want to delete this product?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (shouldDelete == true) {
      setState(() {
        _products.removeAt(_editingIndex!);
      });
      await _persistProducts();
      await _loadProducts();
      _clearForm();
    }
  }

  Future<void> _confirmDeleteProduct(int index) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete product'),
          content: const Text('Are you sure you want to delete this product?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;

    final currentEditingIndex = _editingIndex;
    final deletedEditingProduct = currentEditingIndex == index;

    setState(() {
      _products.removeAt(index);
      if (deletedEditingProduct) {
        _editingIndex = null;
      } else if (currentEditingIndex != null && currentEditingIndex > index) {
        _editingIndex = currentEditingIndex - 1;
      }
    });

    await _persistProducts();
    await _loadProducts();

    if (deletedEditingProduct) {
      _clearForm();
    }
  }

  Future<void> _clearAllProducts() async {
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Clear all products'),
          content: const Text(
            'Are you sure you want to remove all saved products?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Clear', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (shouldClear != true) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('product_master_list');

    await _loadProducts();
    _clearForm();
  }

  Widget _buildSavedProductsSection() {
    return Card(
      color: kCardBlue,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Saved Products',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: kPrimaryBlue,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _products.isEmpty ? null : _clearAllProducts,
                  child: const Text('Clear All'),
                ),
              ],
            ),
            if (_products.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No products added yet',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              )
            else
              SizedBox(
                height: _products.length > 6 ? 360 : (_products.length * 58.0),
                child: ListView.builder(
                  itemCount: _products.length,
                  itemBuilder: (context, index) {
                    final product = _products[index];

                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 4,
                            child: Text(
                              '${product.productCode} - ${product.productName}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: kPrimaryBlue,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              'Stock: ${product.currentStock}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              'Sale: ₹${product.defaultSalePrice.toStringAsFixed(2)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          TextButton(
                            onPressed: () =>
                                _loadForEditByCode(product.productCode),
                            child: const Text('Edit'),
                          ),
                          TextButton(
                            onPressed: () => _confirmDeleteProductByCode(
                              product.productCode,
                            ),
                            child: const Text(
                              'Delete',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
    bool readOnly = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        onChanged: onChanged,
        readOnly: readOnly,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String initialValue,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        initialValue: initialValue,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
        ),
        items: items
            .map(
              (option) => DropdownMenuItem(value: option, child: Text(option)),
            )
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  @override
  void dispose() {
    _productCodeController.removeListener(_checkDuplicateCode);
    _productCodeController.dispose();
    _productNameController.dispose();
    _purchasePriceController.dispose();
    _mrpPriceController.dispose();
    _defaultSalePriceController.dispose();
    _minimumStockAlertController.dispose();
    _currentStockController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final savedProductsCodes = _products
        .map((product) => product.productCode)
        .join(', ');
    debugPrint(
      'ProductMasterPage Saved Products section count=${_products.length}, codes=[$savedProductsCodes]',
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Product Master'), elevation: 0),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final isWide = width >= 1000;
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isWide ? 1200 : double.infinity,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      color: kCardBlue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      elevation: 0,
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Product Master',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: kPrimaryBlue,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Manage products ready for billing, inventory alerts, and future sales search.',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      color: kCardBlue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      elevation: 0,
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Form(
                          key: _formKey,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          child: Column(
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: _buildTextField(
                                      label: 'Product Code *',
                                      controller: _productCodeController,
                                      validator: (value) {
                                        final v = value?.trim() ?? '';
                                        if (v.isEmpty)
                                          return 'Product code is required';
                                        final enteredLower = v.toLowerCase();
                                        final existingIndex = _products
                                            .indexWhere(
                                              (p) =>
                                                  p.productCode
                                                      .trim()
                                                      .toLowerCase() ==
                                                  enteredLower,
                                            );
                                        if (_editingIndex == null) {
                                          if (existingIndex != -1)
                                            return 'Product code already exists';
                                        } else {
                                          if (existingIndex != -1 &&
                                              existingIndex != _editingIndex)
                                            return 'Product code already exists';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildTextField(
                                      label: 'Product Name *',
                                      controller: _productNameController,
                                      validator: (value) =>
                                          value == null || value.trim().isEmpty
                                          ? 'Product name is required'
                                          : null,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: _buildDropdownField(
                                      label: 'Category',
                                      initialValue: _selectedCategory,
                                      items: _categoryOptions,
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedCategory =
                                              value ?? _selectedCategory;
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildDropdownField(
                                      label: 'Unit',
                                      initialValue: _selectedUnit,
                                      items: _unitOptions,
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedUnit =
                                              value ?? _selectedUnit;
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: _buildTextField(
                                      label: 'Purchase Price *',
                                      controller: _purchasePriceController,
                                      keyboardType: TextInputType.number,
                                      validator: (value) =>
                                          value == null || value.trim().isEmpty
                                          ? 'Purchase price is required'
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildTextField(
                                      label: 'MRP Price *',
                                      controller: _mrpPriceController,
                                      keyboardType: TextInputType.number,
                                      validator: (value) =>
                                          value == null || value.trim().isEmpty
                                          ? 'MRP price is required'
                                          : null,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: _buildTextField(
                                      label: 'Default Sale Price *',
                                      controller: _defaultSalePriceController,
                                      keyboardType: TextInputType.number,
                                      validator: (value) =>
                                          value == null || value.trim().isEmpty
                                          ? 'Sale price is required'
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildTextField(
                                      label: 'Minimum Stock Alert *',
                                      controller: _minimumStockAlertController,
                                      keyboardType: TextInputType.number,
                                      validator: (value) =>
                                          value == null || value.trim().isEmpty
                                          ? 'Minimum stock alert is required'
                                          : null,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [],
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  FilledButton(
                                    onPressed: (_isDuplicateCode && !_isEditing)
                                        ? null
                                        : _saveProduct,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: kPrimaryBlue,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                        horizontal: 20,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    child: Text(
                                      _isEditing
                                          ? 'Update Product'
                                          : 'Save Product',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  FilledButton(
                                    onPressed: _isEditing
                                        ? _confirmDelete
                                        : null,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: _isEditing
                                          ? Colors.redAccent
                                          : Colors.grey.shade400,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                        horizontal: 20,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    child: const Text(
                                      'Delete Product',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  OutlinedButton(
                                    onPressed: _clearForm,
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: kPrimaryBlue,
                                      side: const BorderSide(
                                        color: kPrimaryBlue,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                        horizontal: 20,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    child: const Text(
                                      'Clear',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildSavedProductsSection(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class PurchaseBillItem {
  final String productCode;
  final String productName;
  final String unit;
  final int quantity;
  final double purchaseRate;
  final double total;

  const PurchaseBillItem({
    required this.productCode,
    required this.productName,
    required this.unit,
    required this.quantity,
    required this.purchaseRate,
    required this.total,
  });

  factory PurchaseBillItem.fromJson(Map<String, dynamic> json) {
    return PurchaseBillItem(
      productCode: json['productCode'] as String? ?? '',
      productName: json['productName'] as String? ?? '',
      unit: json['unit'] as String? ?? 'Nos',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      purchaseRate: (json['purchaseRate'] as num?)?.toDouble() ?? 0,
      total: (json['total'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'productCode': productCode,
      'productName': productName,
      'unit': unit,
      'quantity': quantity,
      'purchaseRate': purchaseRate,
      'total': total,
    };
  }
}

class PurchaseStockLot {
  final String lotNo;
  final String purchaseNo;
  final String purchaseDate;
  final String supplierName;
  final String productCode;
  final String productName;
  final String unit;
  final int qty;
  final int remainingQty;
  final double purchaseRate;

  const PurchaseStockLot({
    required this.lotNo,
    required this.purchaseNo,
    required this.purchaseDate,
    required this.supplierName,
    required this.productCode,
    required this.productName,
    required this.unit,
    required this.qty,
    required this.remainingQty,
    required this.purchaseRate,
  });

  Map<String, dynamic> toJson() => {
    'lotNo': lotNo,
    'purchaseNo': purchaseNo,
    'purchaseDate': purchaseDate,
    'supplierName': supplierName,
    'productCode': productCode,
    'productName': productName,
    'unit': unit,
    'qty': qty,
    'remainingQty': remainingQty,
    'purchaseRate': purchaseRate,
  };

  factory PurchaseStockLot.fromJson(Map<String, dynamic> json) {
    return PurchaseStockLot(
      lotNo: json['lotNo'] as String? ?? '',
      purchaseNo: json['purchaseNo'] as String? ?? '',
      purchaseDate: json['purchaseDate'] as String? ?? '',
      supplierName: json['supplierName'] as String? ?? '',
      productCode: json['productCode'] as String? ?? '',
      productName: json['productName'] as String? ?? '',
      unit: json['unit'] as String? ?? '',
      qty: json['qty'] as int? ?? 0,
      remainingQty: json['remainingQty'] as int? ?? 0,
      purchaseRate: (json['purchaseRate'] as num?)?.toDouble() ?? 0,
    );
  }
}

class PurchaseBill {
  final String purchaseNo;
  final String purchaseDate;
  final String supplierName;
  final double grandTotal;
  final List<PurchaseBillItem> items;

  const PurchaseBill({
    required this.purchaseNo,
    required this.purchaseDate,
    required this.supplierName,
    required this.grandTotal,
    required this.items,
  });

  factory PurchaseBill.fromJson(Map<String, dynamic> json) {
    return PurchaseBill(
      purchaseNo: json['purchaseNo'] as String? ?? '',
      purchaseDate: json['purchaseDate'] as String? ?? '',
      supplierName: json['supplierName'] as String? ?? '',
      grandTotal: (json['grandTotal'] as num?)?.toDouble() ?? 0,
      items:
          (json['items'] as List<dynamic>?)
              ?.map(
                (item) =>
                    PurchaseBillItem.fromJson(item as Map<String, dynamic>),
              )
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'purchaseNo': purchaseNo,
      'purchaseDate': purchaseDate,
      'supplierName': supplierName,
      'grandTotal': grandTotal,
      'items': items.map((item) => item.toJson()).toList(),
    };
  }
}

class ProductMaster {
  final String productCode;
  final String productName;
  final String category;
  final String unit;
  final double purchasePrice;
  final double mrpPrice;
  final double defaultSalePrice;
  final int minimumStockAlert;
  final int currentStock;

  const ProductMaster({
    required this.productCode,
    required this.productName,
    required this.category,
    required this.unit,
    required this.purchasePrice,
    required this.mrpPrice,
    required this.defaultSalePrice,
    required this.minimumStockAlert,
    required this.currentStock,
  });

  String get code => productCode;
  String get name => productName;
  double get mrp => mrpPrice;
  double get salePrice => defaultSalePrice;
  int get stock => currentStock;

  factory ProductMaster.fromJson(Map<String, dynamic> json) {
    return ProductMaster(
      productCode: json['productCode'] as String? ?? '',
      productName: json['productName'] as String? ?? '',
      category: json['category'] as String? ?? 'Other',
      unit: json['unit'] as String? ?? 'Nos',
      purchasePrice: (json['purchasePrice'] as num?)?.toDouble() ?? 0,
      mrpPrice: (json['mrpPrice'] as num?)?.toDouble() ?? 0,
      defaultSalePrice: (json['defaultSalePrice'] as num?)?.toDouble() ?? 0,
      minimumStockAlert: (json['minimumStockAlert'] as num?)?.toInt() ?? 0,
      currentStock: (json['currentStock'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'productCode': productCode,
      'productName': productName,
      'category': category,
      'unit': unit,
      'purchasePrice': purchasePrice,
      'mrpPrice': mrpPrice,
      'defaultSalePrice': defaultSalePrice,
      'minimumStockAlert': minimumStockAlert,
      'currentStock': currentStock,
    };
  }

  @override
  String toString() => '$productCode $productName';
}

class SaleEntry {
  final ProductMaster product;
  final TextEditingController qtyController;
  final TextEditingController salePriceController;
  final TextEditingController discountController = TextEditingController(
    text: '0',
  );
  int qty;
  String discountType;
  String taxType = 'Inc';

  SaleEntry({required this.product, this.qty = 1, this.discountType = '₹'})
    : qtyController = TextEditingController(text: qty.toString()),
      salePriceController = TextEditingController(
        text: product.defaultSalePrice.toStringAsFixed(2),
      );

  double get salePrice =>
      double.tryParse(salePriceController.text) ?? product.defaultSalePrice;
  double get subtotal => qty * salePrice;
  double get discountValue => double.tryParse(discountController.text) ?? 0;

  double get discountAmount {
    if (discountType == '%') {
      return subtotal * (discountValue / 100.0);
    }
    return discountValue;
  }

  double get total => (subtotal - discountAmount).clamp(0, double.infinity);

  void dispose() {
    qtyController.dispose();
    salePriceController.dispose();
    discountController.dispose();
  }
}

class SaleHistoryProduct {
  final String productCode;
  final String productName;
  final int qty;
  final double mrp;
  final double salePrice;
  final String discountType;
  final double discountValue;
  final double itemTotal;

  SaleHistoryProduct({
    required this.productCode,
    required this.productName,
    required this.qty,
    required this.mrp,
    required this.salePrice,
    required this.discountType,
    required this.discountValue,
    required this.itemTotal,
  });

  Map<String, dynamic> toJson() {
    return {
      'productCode': productCode,
      'productName': productName,
      'qty': qty,
      'mrp': mrp,
      'salePrice': salePrice,
      'discountType': discountType,
      'discountValue': discountValue,
      'itemTotal': itemTotal,
    };
  }

  factory SaleHistoryProduct.fromJson(Map<String, dynamic> json) {
    return SaleHistoryProduct(
      productCode: json['productCode'] as String,
      productName: json['productName'] as String,
      qty: (json['qty'] as num).toInt(),
      mrp: (json['mrp'] as num).toDouble(),
      salePrice: (json['salePrice'] as num).toDouble(),
      discountType: json['discountType'] as String,
      discountValue: (json['discountValue'] as num).toDouble(),
      itemTotal: (json['itemTotal'] as num).toDouble(),
    );
  }
}

class SaleHistoryEntry {
  final String date;
  final String billNo;
  final String saleType;
  final String customer;
  final List<SaleHistoryProduct> items;
  final double grandTotal;
  final double paidAmount;
  final double balance;

  SaleHistoryEntry({
    required this.date,
    required this.billNo,
    required this.saleType,
    required this.customer,
    required this.items,
    required this.grandTotal,
    required this.paidAmount,
    required this.balance,
  });

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'billNo': billNo,
      'saleType': saleType,
      'customer': customer,
      'items': items.map((item) => item.toJson()).toList(),
      'grandTotal': grandTotal,
      'paidAmount': paidAmount,
      'balance': balance,
    };
  }

  factory SaleHistoryEntry.fromJson(Map<String, dynamic> json) {
    return SaleHistoryEntry(
      date: json['date'] as String,
      billNo: json['billNo'] as String,
      saleType: json['saleType'] as String,
      customer: json['customer'] as String,
      items: (json['items'] as List<dynamic>)
          .map(
            (item) => SaleHistoryProduct.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      grandTotal: (json['grandTotal'] as num).toDouble(),
      paidAmount: (json['paidAmount'] as num).toDouble(),
      balance: (json['balance'] as num).toDouble(),
    );
  }
}

class SalesReturnProduct {
  final String productCode;
  final String productName;
  final int soldQty;
  final int returnQty;
  final double salePrice;
  final String discountType;
  final double discountValue;

  SalesReturnProduct({
    required this.productCode,
    required this.productName,
    required this.soldQty,
    required this.returnQty,
    required this.salePrice,
    required this.discountType,
    required this.discountValue,
  });

  factory SalesReturnProduct.fromHistory(SaleHistoryProduct item) {
    return SalesReturnProduct(
      productCode: item.productCode,
      productName: item.productName,
      soldQty: item.qty,
      returnQty: 0,
      salePrice: item.salePrice,
      discountType: item.discountType,
      discountValue: item.discountValue,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'productCode': productCode,
      'productName': productName,
      'soldQty': soldQty,
      'returnQty': returnQty,
      'salePrice': salePrice,
      'discountType': discountType,
      'discountValue': discountValue,
    };
  }

  factory SalesReturnProduct.fromJson(Map<String, dynamic> json) {
    return SalesReturnProduct(
      productCode: json['productCode'] as String? ?? '',
      productName: json['productName'] as String? ?? '',
      soldQty: (json['soldQty'] as num?)?.toInt() ?? 0,
      returnQty: (json['returnQty'] as num?)?.toInt() ?? 0,
      salePrice: (json['salePrice'] as num?)?.toDouble() ?? 0,
      discountType: json['discountType'] as String? ?? '₹',
      discountValue: (json['discountValue'] as num?)?.toDouble() ?? 0,
    );
  }
}

class SalesReturnEntry {
  final String returnDate;
  final String returnNo;
  final String billNo;
  final String customer;
  final List<SalesReturnProduct> items;
  final double returnAmount;

  SalesReturnEntry({
    required this.returnDate,
    required this.returnNo,
    required this.billNo,
    required this.customer,
    required this.items,
    required this.returnAmount,
  });

  Map<String, dynamic> toJson() {
    return {
      'returnDate': returnDate,
      'returnNo': returnNo,
      'billNo': billNo,
      'customer': customer,
      'items': items.map((item) => item.toJson()).toList(),
      'returnAmount': returnAmount,
    };
  }

  factory SalesReturnEntry.fromJson(Map<String, dynamic> json) {
    return SalesReturnEntry(
      returnDate: json['returnDate'] as String? ?? '',
      returnNo: json['returnNo'] as String? ?? '',
      billNo: json['billNo'] as String? ?? '',
      customer: json['customer'] as String? ?? '',
      items:
          (json['items'] as List<dynamic>?)
              ?.map(
                (item) =>
                    SalesReturnProduct.fromJson(item as Map<String, dynamic>),
              )
              .toList() ??
          [],
      returnAmount: (json['returnAmount'] as num?)?.toDouble() ?? 0,
    );
  }
}

class ReturnItem {
  final SaleHistoryProduct item;
  final TextEditingController qtyController;
  int returnQty;

  ReturnItem({required this.item, this.returnQty = 0})
    : qtyController = TextEditingController(text: '0');

  int get soldQty => item.qty;

  double get effectiveUnitPrice {
    if (item.discountType == '%') {
      return item.salePrice * (1 - (item.discountValue / 100));
    }
    final discountPerUnit = item.qty > 0 ? item.discountValue / item.qty : 0;
    final price = item.salePrice - discountPerUnit;
    return price < 0 ? 0 : price;
  }

  double get amount => returnQty * effectiveUnitPrice;

  void dispose() {
    qtyController.dispose();
  }
}

class SalesReturnPage extends StatefulWidget {
  const SalesReturnPage({super.key});

  @override
  State<SalesReturnPage> createState() => _SalesReturnPageState();
}

class _SalesReturnPageState extends State<SalesReturnPage> {
  final _searchController = TextEditingController();
  final List<SaleHistoryEntry> _history = [];
  final List<SaleHistoryEntry> _filteredHistory = [];
  final List<ReturnItem> _returnItems = [];
  final _returnDateController = TextEditingController();
  final _returnNoController = TextEditingController();

  SaleHistoryEntry? _selectedEntry;
  int _lastReturnNumber = 0;
  String _returnNo = 'SR-0001';
  String _returnDate = '';

  @override
  void initState() {
    super.initState();
    _returnDate = _formatDate(DateTime.now());
    _returnDateController.text = _returnDate;
    _searchController.addListener(() => _updateSearch(_searchController.text));
    _loadHistory();
    _loadLastReturnNumber();
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day-$month-$year';
  }

  String _formatReturnNo(int value) => 'SR-${value.toString().padLeft(4, "0")}';

  Future<void> _loadLastReturnNumber() async {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getInt('last_return_number') ?? 0;
    setState(() {
      _lastReturnNumber = last;
      _returnNo = _formatReturnNo(_lastReturnNumber + 1);
      _returnNoController.text = _returnNo;
    });
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('sales_history') ?? [];
    final entries = saved
        .map(
          (entry) => SaleHistoryEntry.fromJson(
            jsonDecode(entry) as Map<String, dynamic>,
          ),
        )
        .toList();
    setState(() {
      _history.clear();
      _history.addAll(entries);
      _filteredHistory.clear();
      _filteredHistory.addAll(entries);
    });
  }

  void _updateSearch(String query) {
    final text = query.trim().toLowerCase();
    setState(() {
      if (text.isEmpty) {
        _filteredHistory
          ..clear()
          ..addAll(_history);
        return;
      }
      _filteredHistory
        ..clear()
        ..addAll(
          _history.where((entry) {
            final billText = entry.billNo.toLowerCase();
            final customerText = entry.customer.toLowerCase();
            return billText.contains(text) || customerText.contains(text);
          }),
        );
    });
  }

  void _selectEntry(SaleHistoryEntry entry) {
    setState(() {
      _selectedEntry = entry;
      _returnItems
        ..clear()
        ..addAll(entry.items.map((item) => ReturnItem(item: item)));
    });
  }

  int get _totalReturnQty =>
      _returnItems.fold(0, (sum, item) => sum + item.returnQty);
  double get _totalReturnAmount =>
      _returnItems.fold(0.0, (sum, item) => sum + item.amount);

  Future<void> _saveReturn() async {
    if (_selectedEntry == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Select a bill first')));
      return;
    }

    if (_returnItems.every((item) => item.returnQty == 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter return quantity for at least one product'),
        ),
      );
      return;
    }

    for (final item in _returnItems) {
      if (item.returnQty > item.soldQty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Return quantity cannot exceed sold quantity'),
          ),
        );
        return;
      }
    }

    final prefs = await SharedPreferences.getInstance();

    final lotSaved = prefs.getStringList('purchase_stock_lot_list') ?? [];
    final lotList = lotSaved
        .map(
          (entry) => PurchaseStockLot.fromJson(
            jsonDecode(entry) as Map<String, dynamic>,
          ),
        )
        .toList();

    final returnQtyByCode = <String, int>{};
    for (final item in _returnItems.where((item) => item.returnQty > 0)) {
      final code = item.item.productCode.trim().toLowerCase();
      if (code.isEmpty) continue;
      returnQtyByCode[code] = (returnQtyByCode[code] ?? 0) + item.returnQty;
    }

    if (returnQtyByCode.isNotEmpty) {
      for (var i = 0; i < lotList.length; i++) {
        final lot = lotList[i];
        final code = lot.productCode.trim().toLowerCase();
        final returnQty = returnQtyByCode[code] ?? 0;
        if (returnQty <= 0) continue;

        lotList[i] = PurchaseStockLot(
          lotNo: lot.lotNo,
          purchaseNo: lot.purchaseNo,
          purchaseDate: lot.purchaseDate,
          supplierName: lot.supplierName,
          productCode: lot.productCode,
          productName: lot.productName,
          unit: lot.unit,
          qty: lot.qty,
          remainingQty: lot.remainingQty + returnQty,
          purchaseRate: lot.purchaseRate,
        );
        returnQtyByCode[code] = 0;
      }
      await prefs.setStringList(
        'purchase_stock_lot_list',
        lotList.map((lot) => jsonEncode(lot.toJson())).toList(),
      );
    }

    final stockByProduct = <String, int>{};
    for (final lot in lotList) {
      final code = lot.productCode.trim().toLowerCase();
      if (code.isEmpty) continue;
      stockByProduct[code] = (stockByProduct[code] ?? 0) + lot.remainingQty;
    }

    final productsSaved = prefs.getStringList('product_master_list') ?? [];
    final products = productsSaved
        .map(
          (entry) =>
              ProductMaster.fromJson(jsonDecode(entry) as Map<String, dynamic>),
        )
        .map((product) {
          final code = product.productCode.trim().toLowerCase();
          final currentStock = stockByProduct[code] ?? 0;
          return ProductMaster(
            productCode: product.productCode,
            productName: product.productName,
            category: product.category,
            unit: product.unit,
            purchasePrice: product.purchasePrice,
            mrpPrice: product.mrpPrice,
            defaultSalePrice: product.defaultSalePrice,
            minimumStockAlert: product.minimumStockAlert,
            currentStock: currentStock,
          );
        })
        .toList();
    await prefs.setStringList(
      'product_master_list',
      products.map((product) => jsonEncode(product.toJson())).toList(),
    );

    final customerName = _selectedEntry?.customer.trim() ?? '';
    if (customerName.isNotEmpty) {
      final savedParties = prefs.getString('parties_list');
      if (savedParties != null && savedParties.isNotEmpty) {
        dynamic decodedParties;
        try {
          decodedParties = jsonDecode(savedParties);
        } catch (_) {
          decodedParties = null;
        }

        if (decodedParties is List) {
          var updated = false;
          final updatedParties = decodedParties.map((party) {
            if (party is! Map) return party;
            final partyMap = Map<String, dynamic>.from(party);
            final partyName = (partyMap['partyName'] ?? '').toString().trim();
            final partyType = (partyMap['partyType'] ?? '').toString();
            final isCustomerParty =
                partyType == 'Customer' || partyType == 'Both';
            if (!updated && isCustomerParty && partyName == customerName) {
              final existingBalance =
                  double.tryParse(
                    (partyMap['openingBalance'] ?? '0').toString(),
                  ) ??
                  0.0;
              final reducedBalance = existingBalance - _totalReturnAmount;
              final newBalance = reducedBalance <= 0 ? 0.0 : reducedBalance;
              partyMap['openingBalance'] = newBalance.toStringAsFixed(2);
              partyMap['balanceType'] = newBalance <= 0 ? 'Zero' : 'Receivable';
              updated = true;
            }
            return partyMap;
          }).toList();

          if (updated) {
            await prefs.setString('parties_list', jsonEncode(updatedParties));
          }
        }
      }
    }

    final savedReturns = prefs.getStringList('sales_return_history') ?? [];
    final returnEntry = SalesReturnEntry(
      returnDate: _returnDateController.text.trim(),
      returnNo: _returnNoController.text.trim(),
      billNo: _selectedEntry!.billNo,
      customer: _selectedEntry!.customer,
      items: _returnItems
          .where((item) => item.returnQty > 0)
          .map(
            (item) => SalesReturnProduct(
              productCode: item.item.productCode,
              productName: item.item.productName,
              soldQty: item.soldQty,
              returnQty: item.returnQty,
              salePrice: item.item.salePrice,
              discountType: item.item.discountType,
              discountValue: item.item.discountValue,
            ),
          )
          .toList(),
      returnAmount: _totalReturnAmount,
    );
    savedReturns.insert(0, jsonEncode(returnEntry.toJson()));
    await prefs.setStringList('sales_return_history', savedReturns);

    final currentReturnNumber = _lastReturnNumber + 1;
    await prefs.setInt('last_return_number', currentReturnNumber);
    _lastReturnNumber = currentReturnNumber;

    setState(() {
      _selectedEntry = null;
      _returnItems.clear();
      _searchController.clear();
      _returnDate = _formatDate(DateTime.now());
      _returnDateController.text = _returnDate;
      _returnNo = _formatReturnNo(_lastReturnNumber + 1);
      _returnNoController.text = _returnNo;
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sales return saved successfully')),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _returnDateController.dispose();
    _returnNoController.dispose();
    for (final item in _returnItems) {
      item.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sales Return'), elevation: 0),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                color: kLightBlue,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Search Previous Sales',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: kPrimaryBlue,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          labelText: 'Search by Bill No or Customer',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _selectedEntry == null
                    ? _buildHistoryList(context)
                    : _buildReturnForm(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryList(BuildContext context) {
    if (_filteredHistory.isEmpty) {
      return const Center(
        child: Text(
          'No sales history found.',
          style: TextStyle(color: Color(0xFF64748B)),
        ),
      );
    }
    return ListView.builder(
      itemCount: _filteredHistory.length,
      itemBuilder: (context, index) {
        final entry = _filteredHistory[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.billNo,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: kPrimaryBlue,
                        ),
                      ),
                    ),
                    FilledButton(
                      onPressed: () => _selectEntry(entry),
                      child: const Text('Select'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    _buildHistoryData('Date', entry.date),
                    _buildHistoryData(
                      'Customer',
                      entry.customer.isEmpty ? 'N/A' : entry.customer,
                    ),
                    _buildHistoryData(
                      'Total',
                      '₹${entry.grandTotal.toStringAsFixed(2)}',
                    ),
                    _buildHistoryData(
                      'Balance',
                      '₹${entry.balance.toStringAsFixed(2)}',
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildReturnForm(BuildContext context) {
    final selected = _selectedEntry!;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            color: kCardBlue,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Return Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: kPrimaryBlue,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      SizedBox(
                        width: 240,
                        height: 70,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Return No',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _returnNoController.text,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: kPrimaryBlue,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 240,
                        height: 70,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Date',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _returnDateController.text,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: kPrimaryBlue,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      SizedBox(
                        width: 240,
                        height: 70,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Bill No',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                selected.billNo,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: kPrimaryBlue,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 420,
                        height: 70,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Customer',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                selected.customer.isEmpty
                                    ? 'N/A'
                                    : selected.customer,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: kPrimaryBlue,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            color: kLightBlue,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Return Items',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: kPrimaryBlue,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Column(
                    children: _returnItems.map((item) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        height: 84,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 320,
                              height: 56,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: kLightBlue,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  '${item.item.productCode} - ${item.item.productName}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: kPrimaryBlue,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 130,
                              height: 56,
                              child: TextField(
                                controller: item.qtyController,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: kPrimaryBlue,
                                ),
                                decoration: InputDecoration(
                                  labelText: 'Qty',
                                  labelStyle: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF64748B),
                                  ),
                                  filled: true,
                                  fillColor: kLightBlue,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 10,
                                  ),
                                ),
                                onChanged: (value) {
                                  var qty = int.tryParse(value) ?? 0;
                                  if (qty < 0) {
                                    qty = 0;
                                  }
                                  item.returnQty = qty;
                                  if (item.qtyController.text !=
                                      qty.toString()) {
                                    item.qtyController.text = qty.toString();
                                    item
                                        .qtyController
                                        .selection = TextSelection.collapsed(
                                      offset: item.qtyController.text.length,
                                    );
                                  }
                                  setState(() {});
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 120,
                              height: 56,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: kLightBlue,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Sale',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '₹${item.item.salePrice.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: kPrimaryBlue,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 190,
                              height: 56,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: kLightBlue,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Return',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '₹${item.amount.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: kPrimaryBlue,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 40,
                              height: 40,
                              child: OutlinedButton(
                                onPressed: () {
                                  setState(() {
                                    item.returnQty = 0;
                                    item.qtyController.text = '0';
                                    _returnItems.remove(item);
                                  });
                                },
                                style: OutlinedButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  side: BorderSide(color: Colors.grey.shade300),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Icon(Icons.delete, size: 18),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: 900,
                    height: 58,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: kLightBlue.withAlpha(40),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 240,
                          height: 46,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Text(
                                  'Total Return',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: Color(0xFF475467),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '₹${_totalReturnAmount.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: kPrimaryBlue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 24),
                        SizedBox(
                          width: 160,
                          height: 46,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Text(
                                  'Total Qty',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: Color(0xFF475467),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _totalReturnQty.toString(),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: kPrimaryBlue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 40),
                        SizedBox(
                          width: 220,
                          height: 46,
                          child: FilledButton(
                            onPressed: _saveReturn,
                            style: FilledButton.styleFrom(
                              backgroundColor: kPrimaryBlue,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text(
                              'Save Return',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        SizedBox(
                          width: 120,
                          height: 46,
                          child: OutlinedButton(
                            onPressed: () {
                              setState(() {
                                _selectedEntry = null;
                                _returnItems.clear();
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: kPrimaryBlue),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: kPrimaryBlue,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: kPrimaryBlue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryData(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: kPrimaryBlue,
            ),
          ),
        ],
      ),
    );
  }
}

class SalesDashboardPage extends StatelessWidget {
  const SalesDashboardPage({super.key});

  static final List<_MenuItem> _salesItems = [
    _MenuItem(label: 'New Sale', icon: Icons.add_shopping_cart),
    _MenuItem(label: 'Sale History', icon: Icons.history),
    _MenuItem(label: 'Sales Return', icon: Icons.undo),
    _MenuItem(label: 'Pending Payments', icon: Icons.pending),
    _MenuItem(label: 'Print / Share', icon: Icons.print),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sales Dashboard'), elevation: 0),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final crossAxisCount = width >= 1200
                ? 3
                : width >= 800
                ? 2
                : 1;
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sales Operations',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: kPrimaryBlue,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Fast access to new invoices, returns, pending collections, and print options.',
                    style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 18),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _salesItems.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      mainAxisExtent: 120,
                    ),
                    itemBuilder: (context, index) {
                      final item = _salesItems[index];
                      return Material(
                        color: kLightBlue,
                        borderRadius: BorderRadius.circular(18),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          splashColor: Colors.transparent,
                          highlightColor: Colors.transparent,
                          hoverColor: Colors.transparent,
                          onTap: () {
                            if (item.label == 'New Sale') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const NewSalePage(),
                                ),
                              );
                            } else if (item.label == 'Sale History') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const SalesHistoryPage(),
                                ),
                              );
                            } else if (item.label == 'Sales Return') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const SalesReturnPage(),
                                ),
                              );
                            } else {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      SectionPage(title: item.label),
                                ),
                              );
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      height: 36,
                                      width: 36,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        item.icon,
                                        color: kPrimaryBlue,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        item.label,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                          color: kPrimaryBlue,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const Text(
                                  'Tap to open',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF475467),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class SalesHistoryPage extends StatefulWidget {
  const SalesHistoryPage({super.key});

  @override
  State<SalesHistoryPage> createState() => _SalesHistoryPageState();
}

class _SalesHistoryPageState extends State<SalesHistoryPage> {
  final _searchController = TextEditingController();
  final List<SaleHistoryEntry> _history = [];
  final List<SaleHistoryEntry> _filteredHistory = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _searchController.addListener(() => _updateSearch(_searchController.text));
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('sales_history') ?? [];
    final entries = saved
        .map(
          (entry) => SaleHistoryEntry.fromJson(
            jsonDecode(entry) as Map<String, dynamic>,
          ),
        )
        .toList();
    setState(() {
      _history.clear();
      _history.addAll(entries);
      _filteredHistory.clear();
      _filteredHistory.addAll(entries);
    });
  }

  void _updateSearch(String query) {
    final text = query.trim().toLowerCase();
    setState(() {
      if (text.isEmpty) {
        _filteredHistory
          ..clear()
          ..addAll(_history);
        return;
      }
      _filteredHistory
        ..clear()
        ..addAll(
          _history.where((entry) {
            final billText = entry.billNo.toLowerCase();
            final customerText = entry.customer.toLowerCase();
            return billText.contains(text) || customerText.contains(text);
          }),
        );
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sale History')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Search by Bill / Estimate No or Customer',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _filteredHistory.isEmpty
                    ? const Center(
                        child: Text(
                          'No sale history found.',
                          style: TextStyle(color: Color(0xFF64748B)),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredHistory.length,
                        itemBuilder: (context, index) {
                          final entry = _filteredHistory[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          entry.billNo,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: kPrimaryBlue,
                                          ),
                                        ),
                                      ),
                                      FilledButton(
                                        onPressed: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                SaleHistoryDetailsPage(
                                                  entry: entry,
                                                ),
                                          ),
                                        ),
                                        child: const Text('View'),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 8,
                                    children: [
                                      _buildHistoryData('Date', entry.date),
                                      _buildHistoryData('Type', entry.saleType),
                                      _buildHistoryData(
                                        'Customer',
                                        entry.customer.isEmpty
                                            ? 'N/A'
                                            : entry.customer,
                                      ),
                                      _buildHistoryData(
                                        'Total',
                                        '₹${entry.grandTotal.toStringAsFixed(2)}',
                                      ),
                                      _buildHistoryData(
                                        'Balance',
                                        '₹${entry.balance.toStringAsFixed(2)}',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryData(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: kLightBlue,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: kPrimaryBlue,
            ),
          ),
        ],
      ),
    );
  }
}

class SaleHistoryDetailsPage extends StatefulWidget {
  final SaleHistoryEntry entry;

  const SaleHistoryDetailsPage({required this.entry, super.key});

  @override
  State<SaleHistoryDetailsPage> createState() => _SaleHistoryDetailsPageState();
}

class _SaleHistoryDetailsPageState extends State<SaleHistoryDetailsPage> {
  late Map<String, bool> _selectedFields;

  @override
  void initState() {
    super.initState();
    _selectedFields = {
      'sno': true,
      'product': true,
      'qty': true,
      'mrp': true,
      'salePrice': true,
      'discount': true,
      'totalAfterDiscount': true,
      'grandTotal': true,
    };
  }

  Widget _buildDetailRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: kPrimaryBlue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckboxTile(String label, String key) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Checkbox(
          value: _selectedFields[key] ?? true,
          onChanged: (val) =>
              setState(() => _selectedFields[key] = val ?? true),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: Colors.black87),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sale Details')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.entry.billNo,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: kPrimaryBlue,
                              ),
                            ),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PrintPreviewPage(
                                  entry: widget.entry,
                                  selectedFields: _selectedFields,
                                ),
                              ),
                            ),
                            child: const Text('Print Preview'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          _buildDetailRow('Date', widget.entry.date),
                          _buildDetailRow('Type', widget.entry.saleType),
                          _buildDetailRow(
                            'Customer',
                            widget.entry.customer.isEmpty
                                ? 'N/A'
                                : widget.entry.customer,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Items',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: kPrimaryBlue,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...widget.entry.items.asMap().entries.map((entry) {
                        final item = entry.value;
                        final index = entry.key;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: kLightBlue,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${index + 1}. ${item.productCode} - ${item.productName}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: kPrimaryBlue,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  _buildDetailRow('Qty', item.qty.toString()),
                                  _buildDetailRow(
                                    'MRP',
                                    '₹${item.mrp.toStringAsFixed(2)}',
                                  ),
                                  _buildDetailRow(
                                    'Sale',
                                    '₹${item.salePrice.toStringAsFixed(2)}',
                                  ),
                                  _buildDetailRow(
                                    'Disc',
                                    '${item.discountType}${item.discountValue.toStringAsFixed(2)}',
                                  ),
                                  _buildDetailRow(
                                    'Total',
                                    '₹${item.itemTotal.toStringAsFixed(2)}',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Grand Total',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF475467),
                            ),
                          ),
                          Text(
                            '₹${widget.entry.grandTotal.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: kPrimaryBlue,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Paid Amount',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF475467),
                            ),
                          ),
                          Text(
                            '₹${widget.entry.paidAmount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: kPrimaryBlue,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Balance',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF475467),
                            ),
                          ),
                          Text(
                            '₹${widget.entry.balance.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: kPrimaryBlue,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Printable Items',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: kPrimaryBlue,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          _buildCheckboxTile('S.No', 'sno'),
                          _buildCheckboxTile('Product Code / Name', 'product'),
                          _buildCheckboxTile('Qty', 'qty'),
                          _buildCheckboxTile('MRP', 'mrp'),
                          _buildCheckboxTile('Sale Price', 'salePrice'),
                          _buildCheckboxTile('Discount', 'discount'),
                          _buildCheckboxTile(
                            'Total after discount',
                            'totalAfterDiscount',
                          ),
                          _buildCheckboxTile('Grand Total', 'grandTotal'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PrintPreviewPage extends StatelessWidget {
  final SaleHistoryEntry entry;
  final Map<String, bool> selectedFields;

  const PrintPreviewPage({
    required this.entry,
    required this.selectedFields,
    super.key,
  });

  String get _headerLabel =>
      entry.saleType.toLowerCase() == 'estimate' ? 'ESTIMATE' : 'BILL';

  List<String> get _visibleColumns {
    final cols = <String>[];
    if (selectedFields['sno'] ?? true) cols.add('sno');
    if (selectedFields['product'] ?? true) cols.add('product');
    if (selectedFields['qty'] ?? true) cols.add('qty');
    if (selectedFields['mrp'] ?? true) cols.add('mrp');
    if (selectedFields['salePrice'] ?? true) cols.add('salePrice');
    if (selectedFields['discount'] ?? true) cols.add('discount');
    if (selectedFields['totalAfterDiscount'] ?? true)
      cols.add('totalAfterDiscount');
    return cols;
  }

  Map<int, TableColumnWidth> get _columnWidths {
    final widths = <int, TableColumnWidth>{};
    int index = 0;
    if (selectedFields['sno'] ?? true)
      widths[index++] = const FixedColumnWidth(36);
    if (selectedFields['product'] ?? true)
      widths[index++] = const FlexColumnWidth(3);
    if (selectedFields['qty'] ?? true)
      widths[index++] = const FixedColumnWidth(48);
    if (selectedFields['mrp'] ?? true)
      widths[index++] = const FixedColumnWidth(72);
    if (selectedFields['salePrice'] ?? true)
      widths[index++] = const FixedColumnWidth(80);
    if (selectedFields['discount'] ?? true)
      widths[index++] = const FixedColumnWidth(80);
    if (selectedFields['totalAfterDiscount'] ?? true)
      widths[index++] = const FixedColumnWidth(90);
    return widths;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Print Preview')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  SizedBox(
                    height: 32,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(70, 32),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        side: const BorderSide(color: kPrimaryBlue, width: 1),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Back',
                        style: TextStyle(color: kPrimaryBlue, fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 32,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(70, 32),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        backgroundColor: kPrimaryBlue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Print option ready.'),
                            duration: Duration(milliseconds: 1200),
                          ),
                        );
                      },
                      child: const Text(
                        'Print',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade300, width: 1.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _headerLabel,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                entry.billNo,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            Text(
                              entry.date,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Customer: ${entry.customer.isEmpty ? 'N/A' : entry.customer}",
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: SingleChildScrollView(
                            child: SizedBox(
                              width: double.infinity,
                              child: Table(
                                border: TableBorder(
                                  top: const BorderSide(
                                    color: Colors.black26,
                                    width: 0.8,
                                  ),
                                  bottom: const BorderSide(
                                    color: Colors.black26,
                                    width: 0.8,
                                  ),
                                  horizontalInside: const BorderSide(
                                    color: Colors.black12,
                                    width: 0.4,
                                  ),
                                  verticalInside: const BorderSide(
                                    color: Colors.black12,
                                    width: 0.4,
                                  ),
                                ),
                                columnWidths: _columnWidths,
                                children: [
                                  TableRow(
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                    ),
                                    children: _visibleColumns.map((col) {
                                      String label = '';
                                      if (col == 'sno') label = 'S.No';
                                      if (col == 'product')
                                        label = 'Product Code / Name';
                                      if (col == 'qty') label = 'Qty';
                                      if (col == 'mrp') label = 'MRP';
                                      if (col == 'salePrice')
                                        label = 'Sale Price';
                                      if (col == 'discount') label = 'Discount';
                                      if (col == 'totalAfterDiscount')
                                        label = 'Total';
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 8,
                                        ),
                                        child: Text(
                                          label,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                  for (final entryItem
                                      in entry.items.asMap().entries)
                                    TableRow(
                                      decoration: BoxDecoration(
                                        color: entryItem.key.isEven
                                            ? Colors.white
                                            : Colors.grey.shade50,
                                      ),
                                      children: _visibleColumns.map((col) {
                                        final item = entryItem.value;
                                        String value = '';
                                        if (col == 'sno')
                                          value = '${entryItem.key + 1}';
                                        if (col == 'product')
                                          value =
                                              '${item.productCode} ${item.productName}';
                                        if (col == 'qty') value = '${item.qty}';
                                        if (col == 'mrp')
                                          value =
                                              '₹${item.mrp.toStringAsFixed(2)}';
                                        if (col == 'salePrice')
                                          value =
                                              '₹${item.salePrice.toStringAsFixed(2)}';
                                        if (col == 'discount')
                                          value =
                                              '${item.discountType}${item.discountValue.toStringAsFixed(2)}';
                                        if (col == 'totalAfterDiscount')
                                          value =
                                              '₹${item.itemTotal.toStringAsFixed(2)}';
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 6,
                                          ),
                                          child: Text(
                                            value,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (selectedFields['grandTotal'] ?? true)
                          const SizedBox(height: 12),
                        if (selectedFields['grandTotal'] ?? true)
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              'Grand Total: ₹${entry.grandTotal.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NewSalePage extends StatefulWidget {
  const NewSalePage({super.key});

  @override
  State<NewSalePage> createState() => _NewSalePageState();
}

class _NewSalePageState extends State<NewSalePage> {
  final _formKey = GlobalKey<FormState>();
  final _customerController = TextEditingController();
  final _paidController = TextEditingController(text: '0');
  final _searchController = TextEditingController();
  final _dateController = TextEditingController();
  final _billController = TextEditingController();
  String _saleType = 'Cash';
  String _searchQuery = '';
  int _lastBillNumber = 0;
  int _lastEstimateNumber = 0;
  String _billNo = '';
  String _saleDate = '';
  final List<ProductMaster> _availableProducts = [];
  final List<ProductMaster> _filteredProducts = [];
  final List<SaleEntry> _saleItems = [];
  final List<Map<String, String>> _customerParties = [];
  final List<Map<String, String>> _filteredCustomerParties = [];

  String get _saleStockDisplay {
    if (_saleItems.isEmpty) return '-';

    final selectedProduct = _saleItems.last.product;
    final selectedCode = selectedProduct.productCode.trim().toLowerCase();
    final matchingIndex = _availableProducts.indexWhere(
      (product) => product.productCode.trim().toLowerCase() == selectedCode,
    );
    final stock = matchingIndex >= 0
        ? _availableProducts[matchingIndex].currentStock
        : selectedProduct.currentStock;
    return stock.toString();
  }

  @override
  void initState() {
    super.initState();
    _saleDate = _formatDate(DateTime.now());
    _dateController.text = _saleDate;
    _searchController.addListener(() => _updateSearch(_searchController.text));
    _loadAvailableProducts();
    _loadLastNumbers();
    _loadCustomerParties();
  }

  Future<void> _loadCustomerParties() async {
    final prefs = await SharedPreferences.getInstance();
    final savedParties = prefs.getString('parties_list');
    if (savedParties == null || savedParties.isEmpty) return;

    final dynamic decodedParties;
    try {
      decodedParties = jsonDecode(savedParties);
    } catch (_) {
      return;
    }
    if (decodedParties is! List) return;

    final parties = decodedParties
        .whereType<Map>()
        .map(
          (party) => party.map(
            (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
          ),
        )
        .where(
          (party) =>
              party['partyType'] == 'Customer' || party['partyType'] == 'Both',
        )
        .toList();

    if (!mounted) return;
    setState(() {
      _customerParties
        ..clear()
        ..addAll(parties);
    });
  }

  void _updateCustomerPartySuggestions(String query) {
    final text = query.trim().toLowerCase();
    setState(() {
      if (text.isEmpty) {
        _filteredCustomerParties.clear();
      } else {
        _filteredCustomerParties
          ..clear()
          ..addAll(
            _customerParties.where((party) {
              final partyName = (party['partyName'] ?? '').toLowerCase();
              final mobile = (party['mobileNumber'] ?? '').toLowerCase();
              return partyName.contains(text) || mobile.contains(text);
            }),
          );
      }
    });
  }

  void _selectCustomerParty(Map<String, String> party) {
    setState(() {
      _customerController.text = party['partyName'] ?? '';
      _filteredCustomerParties.clear();
    });
  }

  Future<void> _loadAvailableProducts() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('product_master_list') ?? [];
    final productMap = <String, ProductMaster>{};

    for (final entry in saved) {
      final product = ProductMaster.fromJson(
        jsonDecode(entry) as Map<String, dynamic>,
      );
      final key = product.productCode.trim().toLowerCase();
      if (key.isEmpty) continue;
      productMap[key] = product;
    }

    setState(() {
      _availableProducts.clear();
      _availableProducts.addAll(productMap.values);
      _filteredProducts.clear();
      _filteredProducts.addAll(_availableProducts);
    });
  }

  void _updateSearch(String query) {
    final text = query.trim().toLowerCase();
    setState(() {
      _searchQuery = query;
      if (text.isEmpty) {
        _filteredProducts.clear();
      } else {
        _filteredProducts
          ..clear()
          ..addAll(
            _availableProducts.where((product) {
              final code = product.productCode.toLowerCase();
              final name = product.productName.toLowerCase();
              return code.contains(text) || name.contains(text);
            }),
          );
      }
    });
  }

  void _selectProduct(ProductMaster product) {
    final key = product.productCode.trim().toLowerCase();
    final existingIndex = _saleItems.indexWhere(
      (item) => item.product.productCode.trim().toLowerCase() == key,
    );
    setState(() {
      if (existingIndex >= 0) {
        final entry = _saleItems[existingIndex];
        entry.qty += 1;
        entry.qtyController.text = entry.qty.toString();
      } else {
        _saleItems.add(SaleEntry(product: product));
      }
      _searchController.clear();
      _filteredProducts.clear();
      _searchQuery = '';
    });
  }

  void _setQuantity(SaleEntry item, int value) {
    item.qty = value < 1 ? 1 : value;
    final text = item.qty.toString();
    item.qtyController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    setState(() {});
  }

  void _handleQuantityChanged(SaleEntry item, String value) {
    final quantity = int.tryParse(value);
    if (quantity == null || quantity < 1) {
      setState(() {});
      return;
    }
    item.qty = quantity;
    setState(() {});
  }

  void _commitQuantity(SaleEntry item) {
    final quantity = int.tryParse(item.qtyController.text.trim());
    if (quantity == null || quantity < 1) {
      _setQuantity(item, 1);
      return;
    }

    item.qty = quantity;
    final text = quantity.toString();
    if (item.qtyController.text != text) {
      item.qtyController.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
    setState(() {});
  }

  void _deleteSaleItem(int index) {
    setState(() {
      _saleItems[index].dispose();
      _saleItems.removeAt(index);
      // If no items remain, reset paid amount and ensure balance shows zero
      if (_saleItems.isEmpty) {
        _paidController.text = '0';
      }
    });
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day-$month-$year';
  }

  String _formatBillNo(int value) => 'BILL-${value.toString().padLeft(4, "0")}';
  String _formatEstimateNo(int value) =>
      'EST-${value.toString().padLeft(4, "0")}';
  String _formatOrderNo(int value) =>
      'ORD-${value.toString().padLeft(4, "0")}';

  bool get _isEstimate => _saleType == 'Estimate';
  String get _numberLabel => _isEstimate ? 'Estimate No' : 'Bill No';
  String get _saveButtonLabel => _isEstimate ? 'Save Estimate' : 'Save Sale';
  String get _successMessage =>
      _isEstimate ? 'Estimate saved successfully' : 'Sale saved successfully';

  String _nextNumberForType(String type) {
    if (type == 'Estimate') {
      return _formatEstimateNo(_lastEstimateNumber + 1);
    }
    if (type == 'Order') {
      return _formatOrderNo(_lastBillNumber + 1);
    }
    return _formatBillNo(_lastBillNumber + 1);
  }

  Future<void> _loadLastNumbers() async {
    final prefs = await SharedPreferences.getInstance();
    final lastBillNumber = prefs.getInt('last_bill_number') ?? 0;
    final lastEstimateNumber = prefs.getInt('last_estimate_number') ?? 0;
    setState(() {
      _lastBillNumber = lastBillNumber;
      _lastEstimateNumber = lastEstimateNumber;
      _billNo = _nextNumberForType(_saleType);
      _billController.text = _billNo;
    });
  }

  Future<void> _saveSaleAndPrepareNext() async {
    await _saveHistoryEntry();
    await _updateSelectedPartyReceivableBalance();
    if (!_isEstimate) {
      await _decrementStockForSale();
      await _loadAvailableProducts();
    }

    final prefs = await SharedPreferences.getInstance();
    if (_isEstimate) {
      final currentEstimateNumber = _lastEstimateNumber + 1;
      await prefs.setInt('last_estimate_number', currentEstimateNumber);
      _lastEstimateNumber = currentEstimateNumber;
    } else {
      final currentBillNumber = _lastBillNumber + 1;
      await prefs.setInt('last_bill_number', currentBillNumber);
      _lastBillNumber = currentBillNumber;
    }

    setState(() {
      _saleItems.clear();
      _customerController.clear();
      _filteredCustomerParties.clear();
      _paidController.text = '0';
      _searchController.clear();
      _searchQuery = '';
      _filteredProducts.clear();
      _filteredProducts.addAll(_availableProducts);
      _saleDate = _formatDate(DateTime.now());
      _dateController.text = _saleDate;
      _billNo = _nextNumberForType(_saleType);
      _billController.text = _billNo;
    });
  }

  Future<void> _decrementStockForSale() async {
    final prefs = await SharedPreferences.getInstance();

    final savedLots = prefs.getStringList('purchase_stock_lot_list') ?? [];
    final lots = savedLots
        .map(
          (entry) => PurchaseStockLot.fromJson(
            jsonDecode(entry) as Map<String, dynamic>,
          ),
        )
        .toList();

    final saleQtyByCode = <String, int>{};
    for (final item in _saleItems) {
      final code = item.product.productCode.trim().toLowerCase();
      if (code.isEmpty) continue;
      saleQtyByCode[code] = (saleQtyByCode[code] ?? 0) + item.qty;
    }

    if (saleQtyByCode.isNotEmpty) {
      final updatedLots = <PurchaseStockLot>[];
      for (final lot in lots) {
        final code = lot.productCode.trim().toLowerCase();
        final remainingSaleQty = saleQtyByCode[code] ?? 0;
        if (remainingSaleQty > 0 && lot.remainingQty > 0) {
          final reduction = remainingSaleQty > lot.remainingQty
              ? lot.remainingQty
              : remainingSaleQty;
          saleQtyByCode[code] = remainingSaleQty - reduction;
          updatedLots.add(
            PurchaseStockLot(
              lotNo: lot.lotNo,
              purchaseNo: lot.purchaseNo,
              purchaseDate: lot.purchaseDate,
              supplierName: lot.supplierName,
              productCode: lot.productCode,
              productName: lot.productName,
              unit: lot.unit,
              qty: lot.qty,
              remainingQty: lot.remainingQty - reduction,
              purchaseRate: lot.purchaseRate,
            ),
          );
        } else {
          updatedLots.add(lot);
        }
      }

      await prefs.setStringList(
        'purchase_stock_lot_list',
        updatedLots.map((lot) => jsonEncode(lot.toJson())).toList(),
      );

      final stockByProduct = <String, int>{};
      for (final lot in updatedLots) {
        final code = lot.productCode.trim().toLowerCase();
        if (code.isEmpty) continue;
        stockByProduct[code] = (stockByProduct[code] ?? 0) + lot.remainingQty;
      }

      final savedProducts = prefs.getStringList('product_master_list') ?? [];
      final updatedProducts = savedProducts
          .map(
            (entry) => ProductMaster.fromJson(
              jsonDecode(entry) as Map<String, dynamic>,
            ),
          )
          .map((product) {
            final code = product.productCode.trim().toLowerCase();
            final currentStock = stockByProduct[code] ?? 0;
            return ProductMaster(
              productCode: product.productCode,
              productName: product.productName,
              category: product.category,
              unit: product.unit,
              purchasePrice: product.purchasePrice,
              mrpPrice: product.mrpPrice,
              defaultSalePrice: product.defaultSalePrice,
              minimumStockAlert: product.minimumStockAlert,
              currentStock: currentStock,
            );
          })
          .toList();

      await prefs.setStringList(
        'product_master_list',
        updatedProducts.map((product) => jsonEncode(product.toJson())).toList(),
      );
    }
  }

  Future<void> _saveHistoryEntry() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('sales_history') ?? [];
    final entry = SaleHistoryEntry(
      date: _dateController.text.trim(),
      billNo: _billController.text.trim(),
      saleType: _saleType,
      customer: _customerController.text.trim(),
      items: _saleItems
          .map(
            (item) => SaleHistoryProduct(
              productCode: item.product.productCode,
              productName: item.product.productName,
              qty: item.qty,
              mrp: item.product.mrpPrice,
              salePrice: item.salePrice,
              discountType: item.discountType,
              discountValue: item.discountValue,
              itemTotal: item.total,
            ),
          )
          .toList(),
      grandTotal: _grandTotal,
      paidAmount: double.tryParse(_paidController.text) ?? 0.0,
      balance: _balance,
    );
    saved.insert(0, jsonEncode(entry.toJson()));
    await prefs.setStringList('sales_history', saved);
  }

  Future<void> _updateSelectedPartyReceivableBalance() async {
    if (_isEstimate) return;

    final saleBalance = _balance;
    final customerName = _customerController.text.trim();
    if (saleBalance <= 0 || customerName.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final savedParties = prefs.getString('parties_list');
    if (savedParties == null || savedParties.isEmpty) return;

    final dynamic decodedParties;
    try {
      decodedParties = jsonDecode(savedParties);
    } catch (_) {
      return;
    }
    if (decodedParties is! List) return;

    var updated = false;
    final updatedParties = decodedParties.map((party) {
      if (party is! Map) return party;

      final partyMap = Map<String, dynamic>.from(party);
      final partyName = (partyMap['partyName'] ?? '').toString().trim();
      final partyType = (partyMap['partyType'] ?? '').toString();
      final isCustomerParty = partyType == 'Customer' || partyType == 'Both';
      if (updated || !isCustomerParty || partyName != customerName)
        return partyMap;

      final existingBalance =
          double.tryParse((partyMap['openingBalance'] ?? '0').toString()) ??
          0.0;
      partyMap['openingBalance'] = (existingBalance + saleBalance)
          .toStringAsFixed(2);
      partyMap['balanceType'] = 'Receivable';
      updated = true;
      return partyMap;
    }).toList();

    if (updated) {
      await prefs.setString('parties_list', jsonEncode(updatedParties));
    }
  }

  void _showSaleSnackBar(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        content: Center(
          child: Text(
            message,
            style: const TextStyle(
              color: kPrimaryBlue,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        behavior: SnackBarBehavior.floating,
        width: 320,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  double get _grandTotal =>
      _saleItems.fold(0.0, (sum, item) => sum + item.total);
  double get _balance {
    if (_saleItems.isEmpty) return 0.0;
    final paid = double.tryParse(_paidController.text) ?? 0.0;
    return _grandTotal - paid;
  }

  Widget _buildField({
    required String label,
    TextEditingController? controller,
    String? initialValue,
    TextInputType keyboardType = TextInputType.text,
    String? hint,
    bool readOnly = false,
    void Function(String)? onChanged,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      initialValue: initialValue,
      keyboardType: keyboardType,
      readOnly: readOnly,
      onChanged: onChanged ?? (_) => setState(() {}),
      validator:
          validator ??
          (value) {
            if (!readOnly &&
                controller == _customerController &&
                (value == null || value.trim().isEmpty)) {
              return 'Customer name is required';
            }
            return null;
          },
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
      ),
    );
  }

  Widget _fixedField({
    required double width,
    required String label,
    TextEditingController? controller,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
    void Function(String)? onChanged,
    String? Function(String?)? validator,
  }) {
    return SizedBox(
      width: width,
      height: 58,
      child: _buildField(
        label: label,
        controller: controller,
        hint: hint,
        keyboardType: keyboardType,
        readOnly: readOnly,
        onChanged: onChanged,
        validator: validator,
      ),
    );
  }

  Widget _buildCustomerPartySuggestions() {
    return Container(
      width: 420,
      height: 220,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: SingleChildScrollView(
        child: Column(
          children: _filteredCustomerParties.map((party) {
            final partyName = party['partyName'] ?? '';
            final mobile = party['mobileNumber'] ?? '';
            final category = party['category'] ?? '';
            return InkWell(
              onTap: () {
                _selectCustomerParty(party);
                FocusScope.of(context).unfocus();
              },
              child: SizedBox(
                height: 52,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 220,
                        child: Text(
                          partyName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: kPrimaryBlue,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 164,
                        child: Text(
                          [
                            mobile,
                            category,
                          ].where((value) => value.isNotEmpty).join(' | '),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildProductSuggestions() {
    return Container(
      width: 1430,
      constraints: const BoxConstraints(maxHeight: 180),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: SingleChildScrollView(
        child: Column(
          children: _filteredProducts.map((product) {
            return InkWell(
              onTap: () {
                _selectProduct(product);
                FocusScope.of(context).unfocus();
              },
              child: SizedBox(
                height: 48,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 1180,
                        child: Text(
                          '${product.productCode} - ${product.productName}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: kPrimaryBlue,
                          ),
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 200,
                        child: Text(
                          'Stock: ${product.currentStock}',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSaleItemRow(int index, SaleEntry item) {
    return SizedBox(
      width: 1436,
      height: 38,
      child: Row(
        children: [
          _saleTableTextCell(
            '${index + 1}',
            width: 64,
            textAlign: TextAlign.center,
          ),
          const SizedBox(width: 6),
          _saleTableTextCell(
            '${item.product.productCode} - ${item.product.productName}',
            width: 352,
            productStyle: true,
          ),
          const SizedBox(width: 6),
          _saleTableTextCell(
            '₹${item.product.purchasePrice.toStringAsFixed(2)}',
            width: 112,
          ),
          const SizedBox(width: 6),
          _saleTableTextCell(
            '₹${item.product.mrpPrice.toStringAsFixed(2)}',
            width: 112,
          ),
          const SizedBox(width: 6),
          _buildQtyControl(item),
          const SizedBox(width: 8),
          _buildNumericField(
            width: 128,
            controller: item.salePriceController,
            onChanged: () => setState(() {}),
          ),
          const SizedBox(width: 6),
          _buildDiscountTypeField(item),
          const SizedBox(width: 8),
          _buildDiscountValueField(item),
          const SizedBox(width: 6),
          _buildTaxTypeField(item),
          const SizedBox(width: 6),
          _saleTableTextCell('0.00', width: 64),
          const SizedBox(width: 6),
          _saleTableTextCell(
            '₹${item.total.toStringAsFixed(2)}',
            width: 150,
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 36,
            height: 46,
            child: Center(
              child: GestureDetector(
                onTap: () => _deleteSaleItem(index),
                child: const Icon(
                  Icons.delete,
                  color: Colors.red,
                  size: 18,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQtyControl(SaleEntry item) {
    return Container(
      width: 82,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: item.qty > 1 ? () => _setQuantity(item, item.qty - 1) : null,
            child: const Icon(Icons.remove, size: 13),
          ),
          const SizedBox(width: 3),
          SizedBox(
            width: 34,
            height: 38,
            child: Focus(
              onFocusChange: (hasFocus) {
                if (!hasFocus) {
                  _commitQuantity(item);
                }
              },
              child: Transform.translate(
                offset: const Offset(0, 2.5),
                child: TextFormField(
                  controller: item.qtyController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  textAlignVertical: TextAlignVertical.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: kPrimaryBlue,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (value) => _handleQuantityChanged(item, value),
                  onEditingComplete: () => _commitQuantity(item),
                ),
              ),
            ),
          ),
          const SizedBox(width: 3),
          GestureDetector(
            onTap: () => _setQuantity(item, item.qty + 1),
            child: const Icon(Icons.add, size: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildNumericField({
    required double width,
    required TextEditingController controller,
    required VoidCallback onChanged,
  }) {
    return SizedBox(
      width: width,
      height: 38,
      child: TextFormField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textAlign: TextAlign.right,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: kPrimaryBlue,
        ),
        onChanged: (_) => onChanged(),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 9,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
        ),
      ),
    );
  }

  Widget _buildDiscountTypeField(SaleEntry item) {
    final GlobalKey discountTypeKey = GlobalKey();

    return Container(
      key: discountTypeKey,
      width: 76,
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          final RenderBox button =
              discountTypeKey.currentContext!.findRenderObject() as RenderBox;
          final OverlayState overlay = Overlay.of(context);
          final RenderBox overlayBox =
              overlay.context.findRenderObject() as RenderBox;

          final Offset position =
              button.localToGlobal(Offset.zero, ancestor: overlayBox);

          late OverlayEntry popupEntry;
          popupEntry = OverlayEntry(
            builder: (context) {
              return Stack(
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: popupEntry.remove,
                      child: Container(color: Colors.transparent),
                    ),
                  ),
                  Positioned(
                    left: position.dx,
                    top: position.dy + button.size.height,
                    width: 76,
                    child: Material(
                      color: Colors.transparent,
                      child: Container(
                        width: 76,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: ['₹', '%'].map((discountType) {
                            return GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                popupEntry.remove();
                                setState(() {
                                  item.discountType = discountType;
                                });
                              },
                              child: Container(
                                width: 76,
                                height: 38,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  discountType,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: kPrimaryBlue,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );

          overlay.insert(popupEntry);
        },
        child: Row(
          children: [
            Expanded(
              child: Text(
                item.discountType,
                style: const TextStyle(
                  fontSize: 13,
                  color: kPrimaryBlue,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Icon(
              Icons.arrow_drop_down,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiscountValueField(SaleEntry item) {
    return Container(
      width: 90,
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: TextFormField(
        controller: item.discountController,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(
          isDense: true,
          border: InputBorder.none,
          hintText: '0',
          contentPadding: EdgeInsets.symmetric(vertical: 8),
        ),
        textAlign: TextAlign.right,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: kPrimaryBlue,
        ),
      ),
    );
  }

  Widget _saleTableHeaderCell(String label, {required double width}) {
    return Container(
      width: width,
      height: 34,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: kPrimaryBlue,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _saleTableTextCell(
    String value, {
    required double width,
    bool productStyle = false,
    TextAlign textAlign = TextAlign.left,
  }) {
    return Container(
      width: width,
      height: 38,
      alignment: textAlign == TextAlign.center
          ? Alignment.center
          : Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        value,
        textAlign: textAlign,
        style: TextStyle(
          fontSize: productStyle ? 14 : 13,
          fontWeight: productStyle ? FontWeight.w600 : FontWeight.w600,
          color: productStyle ? kPrimaryBlue : const Color(0xFF334155),
        ),
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildTaxTypeField(SaleEntry item) {
    final GlobalKey taxTypeKey = GlobalKey();

    return Container(
      key: taxTypeKey,
      width: 88,
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          final RenderBox button =
              taxTypeKey.currentContext!.findRenderObject() as RenderBox;
          final OverlayState overlay = Overlay.of(context);
          final RenderBox overlayBox =
              overlay.context.findRenderObject() as RenderBox;

          final Offset position =
              button.localToGlobal(Offset.zero, ancestor: overlayBox);

          late OverlayEntry popupEntry;
          popupEntry = OverlayEntry(
            builder: (context) {
              return Stack(
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: popupEntry.remove,
                      child: Container(color: Colors.transparent),
                    ),
                  ),
                  Positioned(
                    left: position.dx,
                    top: position.dy + button.size.height,
                    width: 88,
                    child: Material(
                      color: Colors.transparent,
                      child: Container(
                        width: 88,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: ['Inc', 'Exc'].map((taxType) {
                            return GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                popupEntry.remove();
                                setState(() {
                                  item.taxType = taxType;
                                });
                              },
                              child: Container(
                                width: 88,
                                height: 38,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  taxType,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF334155),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );

          overlay.insert(popupEntry);
        },
        child: Row(
          children: [
            Expanded(
              child: Text(
                item.taxType,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF334155),
                ),
              ),
            ),
            const Icon(
              Icons.arrow_drop_down,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _saleTotalDisplayBox(
    String label,
    String value, {
    required double width,
  }) {
    return Container(
      width: width,
      height: 96,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: kPrimaryBlue,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _customerController.dispose();
    _paidController.dispose();
    _searchController.dispose();
    _dateController.dispose();
    _billController.dispose();
    for (final item in _saleItems) {
      item.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Sale'),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        color: const Color(0xFFF6F8FB),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(30, 28, 30, 24),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 1476,
                    height: 234,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: kLightBlue,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300, width: 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      const Text(
                        'Sale Details',
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: kPrimaryBlue,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          SizedBox(
                            width: 315,
                            height: 60,
                            child: _buildField(
                              label: 'Date',
                              controller: _dateController,
                            ),
                          ),
                          const SizedBox(width: 30),
                          SizedBox(
                            width: 405,
                            height: 60,
                            child: _buildField(
                              label: 'Customer',
                              controller: _customerController,
                              hint: 'Customer',
                              onChanged: _updateCustomerPartySuggestions,
                            ),
                          ),
                          const SizedBox(width: 30),
                          Builder(
                            builder: (context) {
                              final GlobalKey saleTypeKey = GlobalKey();

                              return SizedBox(
                                key: saleTypeKey,
                                width: 274,
                                height: 60,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () {
                                    final RenderBox button = saleTypeKey
                                        .currentContext!
                                        .findRenderObject() as RenderBox;
                                    final OverlayState overlay =
                                        Overlay.of(context);
                                    final RenderBox overlayBox = overlay.context
                                        .findRenderObject() as RenderBox;

                                    final Offset position = button.localToGlobal(
                                      Offset.zero,
                                      ancestor: overlayBox,
                                    );

                                    late OverlayEntry popupEntry;
                                    popupEntry = OverlayEntry(
                                      builder: (context) {
                                        return Stack(
                                          children: [
                                            Positioned.fill(
                                              child: GestureDetector(
                                                behavior:
                                                    HitTestBehavior.opaque,
                                                onTap: popupEntry.remove,
                                                child: Container(
                                                  color: Colors.transparent,
                                                ),
                                              ),
                                            ),
                                            Positioned(
                                              left: position.dx,
                                              top:
                                                  position.dy + button.size.height,
                                              width: button.size.width,
                                              child: Material(
                                                color: Colors.transparent,
                                                child: Container(
                                                  width: button.size.width,
                                                  decoration: BoxDecoration(
                                                    color: Colors.white,
                                                    borderRadius:
                                                        BorderRadius.circular(8),
                                                    border: Border.all(
                                                      color: Colors.grey.shade300,
                                                    ),
                                                  ),
                                                  clipBehavior: Clip.antiAlias,
                                                  child: Column(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      'Cash',
                                                      'Credit',
                                                      'Estimate',
                                                      'Order',
                                                    ].map((saleType) {
                                                      return GestureDetector(
                                                        behavior: HitTestBehavior
                                                            .opaque,
                                                        onTap: () {
                                                          popupEntry.remove();
                                                          setState(() {
                                                            _saleType = saleType;
                                                            _billNo =
                                                                _nextNumberForType(
                                                                  _saleType,
                                                                );
                                                            _billController.text =
                                                                _billNo;
                                                          });
                                                        },
                                                        child: Container(
                                                          width:
                                                              button.size.width,
                                                          height: 44,
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 12,
                                                                vertical: 12,
                                                              ),
                                                          alignment: Alignment
                                                              .centerLeft,
                                                          child: Text(
                                                            saleType,
                                                            style: Theme.of(context)
                                                                .textTheme
                                                                .titleMedium
                                                                ?.copyWith(
                                                                  fontSize: 18,
                                                                ),
                                                          ),
                                                        ),
                                                      );
                                                    }).toList(),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    );

                                    overlay.insert(popupEntry);
                                  },
                                  child: InputDecorator(
                                    isEmpty: false,
                                    decoration: InputDecoration(
                                      labelText: 'Sale Type',
                                      filled: true,
                                      fillColor: Colors.white,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 12,
                                          ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                          color: Colors.grey.shade300,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            _saleType,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium,
                                          ),
                                        ),
                                        const Icon(Icons.arrow_drop_down),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 30),
                          SizedBox(
                            width: 344,
                            height: 60,
                            child: _buildField(
                              label: _numberLabel,
                              controller: _billController,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: 1430,
                        height: 58,
                        child: TextFormField(
                          controller: _searchController,
                          onChanged: _updateSearch,
                          decoration: InputDecoration(
                            labelText: 'Product Search',
                            hintText: 'Search product code or product name',
                            filled: true,
                            fillColor: Colors.white,
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () => _searchController.clear(),
                                  )
                                : null,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                          ),
                        ),
                      ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: 1476,
                    height: 342,
                    child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: kLightBlue,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300, width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const SizedBox(
                            width: 1195,
                            child: Text(
                              'Sale Items Bill Table',
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                                color: kPrimaryBlue,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 240,
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                'Stock : $_saleStockDisplay',
                                maxLines: 1,
                                softWrap: false,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: 1436,
                        height: 46,
                        child: Row(
                          children: [
                            _saleTableHeaderCell('S.No', width: 64),
                            const SizedBox(width: 6),
                            _saleTableHeaderCell('Product', width: 352),
                            const SizedBox(width: 6),
                            _saleTableHeaderCell('Purchase', width: 112),
                            const SizedBox(width: 6),
                            _saleTableHeaderCell('MRP', width: 112),
                            const SizedBox(width: 6),
                            _saleTableHeaderCell('Qty', width: 82),
                            const SizedBox(width: 8),
                            _saleTableHeaderCell('Sale Price', width: 128),
                            const SizedBox(width: 6),
                            _saleTableHeaderCell('₹/%', width: 76),
                            const SizedBox(width: 8),
                            _saleTableHeaderCell('Discount', width: 90),
                            const SizedBox(width: 6),
                            _saleTableHeaderCell('Tax Type', width: 88),
                            const SizedBox(width: 6),
                            _saleTableHeaderCell('Tax %', width: 64),
                            const SizedBox(width: 6),
                            _saleTableHeaderCell('Total', width: 150),
                            const SizedBox(width: 6),
                            SizedBox(
                              width: 36,
                              height: 46,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_saleItems.isEmpty)
                        const SizedBox(
                          width: 1440,
                          height: 126,
                          child: Center(
                            child: Text(
                              'Add products to start the sale.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        )
                      else
                        Column(
                          children: List.generate(
                            _saleItems.length,
                            (index) => _buildSaleItemRow(
                              index,
                              _saleItems[index],
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: 140,
                        height: 48,
                        child: OutlinedButton(
                          onPressed: () {},
                          child: const Text('+ Add Item'),
                        ),
                      ),
                    ],
                  ),
                    ),
                  ),
                ],
              ),
              if (_filteredCustomerParties.isNotEmpty)
                Positioned(
                  left: 365,
                  top: 132,
                  child: _buildCustomerPartySuggestions(),
                ),
              if (_searchQuery.trim().isNotEmpty && _filteredProducts.isNotEmpty)
                Positioned(
                  left: 20,
                  top: 210,
                  child: _buildProductSuggestions(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
