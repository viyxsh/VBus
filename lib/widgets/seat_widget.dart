import 'package:flutter/material.dart';

class SeatWidget extends StatelessWidget {
  final String seatNumber;
  final bool isTaken;
  final bool isSelected;
  final bool isFaculty;
  final String userType;
  final Function(String?) onTap;
  final Function(String) onTakenTap;

  const SeatWidget({
    super.key,
    required this.seatNumber,
    required this.isTaken,
    required this.isSelected,
    required this.isFaculty,
    required this.userType,
    required this.onTap,
    required this.onTakenTap,
  });
  // determine if the seat can be selected:
  // - the seat must not be taken (!isTaken).
  // - faculty seats can only be selected by faculty users and vice versa
  @override
  Widget build(BuildContext context) {
    final bool canSelect = !isTaken && ((isFaculty && userType == 'faculty') || (!isFaculty && userType == 'student'));

    return GestureDetector(
      onTap: () {
        if (isTaken) {
          onTakenTap(seatNumber);
        } else if (canSelect) {
          onTap(isSelected ? null : seatNumber);
        }
      },
      // render seat UI
      child: Container(
        height: 40,
        width: 40,
        decoration: BoxDecoration(
          color: isTaken
              ? Colors.grey[400]
              : isSelected
              ? (isFaculty ? Colors.orange : Colors.red)
              : Colors.white,
          border: !isTaken
              ? Border.all(
            color: isFaculty ? Colors.orange : Colors.red,
            width: 2,
          )
              : null,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: isTaken
              ? const Icon(Icons.clear, size: 18)
              : Text(
            seatNumber,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: isSelected ? Colors.white : Colors.black,
            ),
          ),
        ),
      ),
    );
  }
}