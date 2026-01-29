import 'package:flutter/material.dart';

class Invoice {
  final String id;
  final String invoiceNo;
  final String customerId;
  final int invoiceDate;
  final double subtotal;
  final double discountPercent;
  final double discountAmount;
  final double gstAmount;
  final double roundOff;
  final double total;
  final double paidAmount;
  final double balanceAmount;
  final String paymentType;
  final String? notes;
  final String? pdfPath;
  final int createdAt;

  Invoice({
    required this.id,
    required this.invoiceNo,
    required this.customerId,
    required this.invoiceDate,
    required this.subtotal,
    required this.discountPercent,
    required this.discountAmount,
    required this.gstAmount,
    required this.roundOff,
    required this.total,
    required this.paidAmount,
    required this.balanceAmount,
    required this.paymentType,
    this.notes,
    this.pdfPath,
    required this.createdAt,
  });

  Invoice copyWith({
    String? id,
    String? invoiceNo,
    String? customerId,
    int? invoiceDate,
    double? subtotal,
    double? discountPercent,
    double? discountAmount,
    double? gstAmount,
    double? roundOff,
    double? total,
    double? paidAmount,
    double? balanceAmount,
    String? paymentType,
    String? notes,
    String? pdfPath,
    int? createdAt,
  }) {
    return Invoice(
      id: id ?? this.id,
      invoiceNo: invoiceNo ?? this.invoiceNo,
      customerId: customerId ?? this.customerId,
      invoiceDate: invoiceDate ?? this.invoiceDate,
      subtotal: subtotal ?? this.subtotal,
      discountPercent: discountPercent ?? this.discountPercent,
      discountAmount: discountAmount ?? this.discountAmount,
      gstAmount: gstAmount ?? this.gstAmount,
      roundOff: roundOff ?? this.roundOff,
      total: total ?? this.total,
      paidAmount: paidAmount ?? this.paidAmount,
      balanceAmount: balanceAmount ?? this.balanceAmount,
      paymentType: paymentType ?? this.paymentType,
      notes: notes ?? this.notes,
      pdfPath: pdfPath ?? this.pdfPath,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
