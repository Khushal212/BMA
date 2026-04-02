import 'package:drift/drift.dart';

class Customers extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get phone => text()();
  TextColumn get address => text().nullable()();
  RealColumn get creditLimit =>
      real().withDefault(const Constant(10000))();
  RealColumn get defaultPricePercent => real().nullable()();
  RealColumn get defaultGstPercent =>
      real().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

class Items extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get unit => text()();
  RealColumn get defaultRate => real().nullable()();
  RealColumn get gstPercent =>
      real().withDefault(const Constant(0))();
  // Stock tracking columns
  RealColumn get currentStock =>
      real().withDefault(const Constant(0))();
  RealColumn get lowStockAlert =>
      real().withDefault(const Constant(10))();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

class Invoices extends Table {
  TextColumn get id => text()();
  TextColumn get invoiceNo => text()();
  TextColumn get customerId => text()();
  IntColumn get invoiceDate => integer()();
  RealColumn get subtotal => real()();
  RealColumn get discountPercent =>
      real().withDefault(const Constant(0))();
  RealColumn get discountAmount =>
      real().withDefault(const Constant(0))();
  RealColumn get gstAmount => real()();
  RealColumn get roundOff =>
      real().withDefault(const Constant(0))();
  RealColumn get total => real()();
  RealColumn get paidAmount =>
      real().withDefault(const Constant(0))();
  RealColumn get balanceAmount => real()();
  TextColumn get paymentType => text()();
  TextColumn get notes => text().nullable()();
  TextColumn get pdfPath => text().nullable()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

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
}

class Payments extends Table {
  TextColumn get id => text()();
  TextColumn get customerId => text()();
  IntColumn get paymentDate => integer()();
  RealColumn get amount => real()();
  TextColumn get mode => text()();
  TextColumn get reference => text().nullable()();
  TextColumn get notes => text().nullable()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

// Stock movements log
class StockMovements extends Table {
  TextColumn get id => text()();
  TextColumn get itemId => text()();
  RealColumn get quantity => real()(); // positive=in, negative=out
  TextColumn get type => text()(); // PURCHASE, INVOICE, ADJUSTMENT
  TextColumn get referenceId => text().nullable()(); // invoiceId etc
  TextColumn get notes => text().nullable()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
