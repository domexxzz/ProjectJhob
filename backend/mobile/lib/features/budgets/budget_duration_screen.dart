import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';

class BudgetDurationScreen extends StatefulWidget {
  const BudgetDurationScreen({super.key});

  @override
  State<BudgetDurationScreen> createState() => _BudgetDurationScreenState();
}

class _BudgetDurationScreenState extends State<BudgetDurationScreen> {
  // Mock calendar state
  int _selectedDay = 7;
  bool _showDropdown = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        centerTitle: true,
        title: const Text('กำหนดระยะเวลา', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const SizedBox(height: 16),
                // Header Icon and Name
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.3),
                              blurRadius: 20,
                              spreadRadius: 10,
                            )
                          ],
                          border: Border.all(color: AppColors.primary, width: 2),
                        ),
                        child: const Center(
                          child: Text('🏝️', style: TextStyle(fontSize: 48)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'เที่ยวต่างประเทศ',
                        style: TextStyle(color: AppColors.primary, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Calendar Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1C),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Column(
                    children: [
                      // Month/Year Selector row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Color(0xFF262626),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.chevron_left, color: Colors.white, size: 20),
                          ),
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _showDropdown = !_showDropdown;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF262626),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: const [
                                      Text('April', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                      SizedBox(width: 4),
                                      Icon(Icons.arrow_drop_down, color: AppColors.primary),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF262626),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: const [
                                    Text('2026', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                    SizedBox(width: 4),
                                    Icon(Icons.arrow_drop_down, color: AppColors.primary),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Color(0xFF262626),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.chevron_right, color: Colors.white, size: 20),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Days of week
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: const [
                          Text('Mo', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
                          Text('Tu', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
                          Text('We', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
                          Text('Th', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
                          Text('Fr', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
                          Text('Sa', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
                          Text('Su', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Calendar grid (mock data for appearance)
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                        ),
                        itemCount: 35,
                        itemBuilder: (context, index) {
                          // Mock offset for April 2026 (starts on Wed)
                          int day = index - 1; // 0-indexed offset
                          
                          bool isOtherMonth = day < 1 || day > 30;
                          String text = isOtherMonth ? (day < 1 ? '${29 + day}' : '${day - 30}') : '$day';
                          bool isSelected = day == _selectedDay;

                          return GestureDetector(
                            onTap: () {
                              if (!isOtherMonth) {
                                setState(() {
                                  _selectedDay = day;
                                });
                              }
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.primary : const Color(0xFF262626),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  text,
                                  style: TextStyle(
                                    color: isOtherMonth ? Colors.white24 : Colors.white,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const Spacer(),
                
                // Next Button
                SizedBox(
                  width: 160,
                  child: ElevatedButton(
                    onPressed: () {
                      context.pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('ต่อไป', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
          
          // Dropdown Mock Overlay
          if (_showDropdown)
            Positioned(
              top: 240,
              left: MediaQuery.of(context).size.width / 2 - 90,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: 140,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 5)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDropdownItem('January', false),
                      _buildDropdownItem('February', false),
                      _buildDropdownItem('March', false),
                      _buildDropdownItem('April', true),
                      _buildDropdownItem('May', false),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDropdownItem(String text, bool isSelected) {
    return InkWell(
      onTap: () {
        setState(() {
          _showDropdown = false;
        });
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? AppColors.primary : Colors.black87,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
