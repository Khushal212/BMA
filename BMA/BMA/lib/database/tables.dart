import 'package:drift/drift.dart';

// Customers Table
class Customers extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get phone => text()();
  TextColumn get address => text().nullable()();
  RealColumn get creditLimit => real().withDefault(const Constant(10000))();
  RealColumn get defaultPricePercent => real().nullable()();
  RealColumn get defaultGstPercent => real().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

// Items Table
class Items extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get unit => text()(); // kg, crate, bunch, box
  RealColumn get defaultRate => real().nullable()();
  RealColumn get gstPercent => real().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

// Invoices Table
class Invoices extends Table {
  TextColumn get id => text()();
  TextColumn get invoiceNo => text().unique()();
  TextColumn get customerId => text()();
  IntColumn get invoiceDate => integer()();
  RealColumn get subtotal => real()();
  RealColumn get discountPercent => real().withDefault(const Constant(0))();
  RealColumn get discountAmount => real().withDefault(const Constant(0))();
  RealColumn get gstAmount => real()();
  RealColumn get roundOff => real().withDefault(const Constant(0))();
  RealColumn get total => real()();
  RealColumn get paidAmount => real().withDefault(const Constant(0))();
  RealColumn get balanceAmount => real()();
  TextColumn get paymentType => text()(); // CASH, UPI, BANK, CREDIT, MIXED
  TextColumn get notes => text().nullable()();
  TextColumn get pdfPath => text().nullable()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
  @override
  List<Set<Column>> get uniqueKeys => [
    {invoiceNo}
  ];
}

// Invoice Lines Table
class InvoiceLines extends Table {
  TextColumn get id => text()();
  TextColumn get invoiceId => text()();
  TextColumn get itemId => text()();
  TextColumn get itemNameSnapshot => text()();
  RealColumn get qty => real()();
  TextColumn get unit => text()();
  RealColumn get rate => real()();
  RealColumn get lineSubtotal => real()();
  RealColumn get lineGstPercent => real()();
  RealColumn get lineGstAmount => real()();
  RealColumn get lineTotal => real()();

  @override
  Set<Column> get primaryKey => {id};
  @override
  List<Set<Column>> get uniqueKeys => [
    {invoiceId, itemId}
  ];
}

// Payments Table
class Payments extends Table {
  TextColumn get id => text()();
  TextColumn get customerId => text()();
  IntColumn get paymentDate => integer()();
  RealColumn get amount => real()();
  TextColumn get mode => text()(); // CASH, UPI, BANK
  TextColumn get reference => text().nullable()();
  TextColumn get notes => text().nullable()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

// Settings Table
class Settings extends Table {
  TextColumn get key => text().unique()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
