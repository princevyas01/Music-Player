import 'package:flutter/material.dart';

/// Translucent Cassette Tape Graphic matching the left screen of reference image 2
class CassetteTapeWidget extends StatelessWidget {
  final double width;
  final double height;

  const CassetteTapeWidget({
    super.key,
    this.width = 220,
    this.height = 140,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.1), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Top Tape Header: "B TYPE I / IEC I NORMAL"
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black, width: 1.5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'B',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
              const Text(
                'TYPE I / IEC I NORMAL',
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Tape Spools Window
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F0ED),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black.withOpacity(0.08)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Left Spool
                  _buildSpool(),
                  // Center Tape Text
                  const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('E', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black45)),
                      Text('SONY', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.black38)),
                    ],
                  ),
                  // Right Spool
                  _buildSpool(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Bottom Tape Footer: "90"
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '90',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black45),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpool() {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: Colors.black26, width: 1.5),
      ),
      child: Center(
        child: Container(
          width: 16,
          height: 16,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFF222228),
          ),
        ),
      ),
    );
  }
}
