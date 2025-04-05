import 'package:flutter/material.dart';
import 'package:vbuss/widgets/seat_widget.dart';

class Bus1Layout extends StatelessWidget {
  final String? selectedSeat;
  final Set<String> takenSeats;
  final String userType;
  final Function(String?) onSeatSelected;
  final Function(String) onTakenSeatTapped;

  const Bus1Layout({
    super.key,
    required this.selectedSeat,
    required this.takenSeats,
    required this.userType,
    required this.onSeatSelected,
    required this.onTakenSeatTapped,
  });
  //faculty seats
  bool _isFacultySeat(String seatNumber) {
    if (seatNumber.startsWith('L')) {
      int seatNum = int.parse(seatNumber.substring(1));
      return seatNum <= 8;
    } else if (seatNumber.startsWith('R')) {
      int seatNum = int.parse(seatNumber.substring(1));
      return seatNum <= 18;
    }
    return false; //student seats
  }
  //column stack to contain:
  // - one r with two c (lhs and rhs of the bus):
  // -- lhs seats: cond box at the top, 8 r of 2 seats (L1–L16) using one loop
  // - one empty row for aisle
  // - 1 r with seats L17–L18.
  // -- rhs: 10 rows of 3 seats (R1–R30), using two loops (6 r then 4 r).
  // -- last row with 6 back seats (B1–B6).
  @override
  Widget build(BuildContext context) {
    // enable vertical scrolling
    return SingleChildScrollView(
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 300),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Center(
                              child: Text(
                                "Conductor",
                                style: TextStyle(fontSize: 7, color: Colors.grey),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const SizedBox(width: 40, height: 40),
                        ],
                      ),
                      const SizedBox(height: 16),
                      for (int i = 0; i < 8; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SeatWidget(
                                seatNumber: 'L${i * 2 + 1}',
                                isTaken: takenSeats.contains('L${i * 2 + 1}'),
                                isSelected: selectedSeat == 'L${i * 2 + 1}',
                                isFaculty: _isFacultySeat('L${i * 2 + 1}'),
                                userType: userType,
                                onTap: onSeatSelected,
                                onTakenTap: onTakenSeatTapped,
                              ),
                              const SizedBox(width: 8),
                              SeatWidget(
                                seatNumber: 'L${i * 2 + 2}',
                                isTaken: takenSeats.contains('L${i * 2 + 2}'),
                                isSelected: selectedSeat == 'L${i * 2 + 2}',
                                isFaculty: _isFacultySeat('L${i * 2 + 2}'),
                                userType: userType,
                                onTap: onSeatSelected,
                                onTakenTap: onTakenSeatTapped,
                              ),
                            ],
                          ),
                        ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(width: 40, height: 40),
                          const SizedBox(width: 8),
                          const SizedBox(width: 40, height: 40),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SeatWidget(
                            seatNumber: 'L17',
                            isTaken: takenSeats.contains('L17'),
                            isSelected: selectedSeat == 'L17',
                            isFaculty: _isFacultySeat('L17'),
                            userType: userType,
                            onTap: onSeatSelected,
                            onTakenTap: onTakenSeatTapped,
                          ),
                          const SizedBox(width: 8),
                          SeatWidget(
                            seatNumber: 'L18',
                            isTaken: takenSeats.contains('L18'),
                            isSelected: selectedSeat == 'L18',
                            isFaculty: _isFacultySeat('L18'),
                            userType: userType,
                            onTap: onSeatSelected,
                            onTakenTap: onTakenSeatTapped,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(width: 32),
                  Column(
                    children: [
                      const SizedBox(height: 28),
                      for (int i = 0; i < 6; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SeatWidget(
                                seatNumber: 'R${i * 3 + 1}',
                                isTaken: takenSeats.contains('R${i * 3 + 1}'),
                                isSelected: selectedSeat == 'R${i * 3 + 1}',
                                isFaculty: _isFacultySeat('R${i * 3 + 1}'),
                                userType: userType,
                                onTap: onSeatSelected,
                                onTakenTap: onTakenSeatTapped,
                              ),
                              const SizedBox(width: 8),
                              SeatWidget(
                                seatNumber: 'R${i * 3 + 2}',
                                isTaken: takenSeats.contains('R${i * 3 + 2}'),
                                isSelected: selectedSeat == 'R${i * 3 + 2}',
                                isFaculty: _isFacultySeat('R${i * 3 + 2}'),
                                userType: userType,
                                onTap: onSeatSelected,
                                onTakenTap: onTakenSeatTapped,
                              ),
                              const SizedBox(width: 8),
                              SeatWidget(
                                seatNumber: 'R${i * 3 + 3}',
                                isTaken: takenSeats.contains('R${i * 3 + 3}'),
                                isSelected: selectedSeat == 'R${i * 3 + 3}',
                                isFaculty: _isFacultySeat('R${i * 3 + 3}'),
                                userType: userType,
                                onTap: onSeatSelected,
                                onTakenTap: onTakenSeatTapped,
                              ),
                            ],
                          ),
                        ),
                      for (int i = 6; i < 10; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SeatWidget(
                                seatNumber: 'R${i * 3 + 1}',
                                isTaken: takenSeats.contains('R${i * 3 + 1}'),
                                isSelected: selectedSeat == 'R${i * 3 + 1}',
                                isFaculty: _isFacultySeat('R${i * 3 + 1}'),
                                userType: userType,
                                onTap: onSeatSelected,
                                onTakenTap: onTakenSeatTapped,
                              ),
                              const SizedBox(width: 8),
                              SeatWidget(
                                seatNumber: 'R${i * 3 + 2}',
                                isTaken: takenSeats.contains('R${i * 3 + 2}'),
                                isSelected: selectedSeat == 'R${i * 3 + 2}',
                                isFaculty: _isFacultySeat('R${i * 3 + 2}'),
                                userType: userType,
                                onTap: onSeatSelected,
                                onTakenTap: onTakenSeatTapped,
                              ),
                              const SizedBox(width: 8),
                              SeatWidget(
                                seatNumber: 'R${i * 3 + 3}',
                                isTaken: takenSeats.contains('R${i * 3 + 3}'),
                                isSelected: selectedSeat == 'R${i * 3 + 3}',
                                isFaculty: _isFacultySeat('R${i * 3 + 3}'),
                                userType: userType,
                                onTap: onSeatSelected,
                                onTakenTap: onTakenSeatTapped,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SeatWidget(
                    seatNumber: 'B1',
                    isTaken: takenSeats.contains('B1'),
                    isSelected: selectedSeat == 'B1',
                    isFaculty: _isFacultySeat('B1'),
                    userType: userType,
                    onTap: onSeatSelected,
                    onTakenTap: onTakenSeatTapped,
                  ),
                  const SizedBox(width: 4),
                  SeatWidget(
                    seatNumber: 'B2',
                    isTaken: takenSeats.contains('B2'),
                    isSelected: selectedSeat == 'B2',
                    isFaculty: _isFacultySeat('B2'),
                    userType: userType,
                    onTap: onSeatSelected,
                    onTakenTap: onTakenSeatTapped,
                  ),
                  const SizedBox(width: 4),
                  SeatWidget(
                    seatNumber: 'B3',
                    isTaken: takenSeats.contains('B3'),
                    isSelected: selectedSeat == 'B3',
                    isFaculty: _isFacultySeat('B3'),
                    userType: userType,
                    onTap: onSeatSelected,
                    onTakenTap: onTakenSeatTapped,
                  ),
                  const SizedBox(width: 4),
                  SeatWidget(
                    seatNumber: 'B4',
                    isTaken: takenSeats.contains('B4'),
                    isSelected: selectedSeat == 'B4',
                    isFaculty: _isFacultySeat('B4'),
                    userType: userType,
                    onTap: onSeatSelected,
                    onTakenTap: onTakenSeatTapped,
                  ),
                  const SizedBox(width: 4),
                  SeatWidget(
                    seatNumber: 'B5',
                    isTaken: takenSeats.contains('B5'),
                    isSelected: selectedSeat == 'B5',
                    isFaculty: _isFacultySeat('B5'),
                    userType: userType,
                    onTap: onSeatSelected,
                    onTakenTap: onTakenSeatTapped,
                  ),
                  const SizedBox(width: 4),
                  SeatWidget(
                    seatNumber: 'B6',
                    isTaken: takenSeats.contains('B6'),
                    isSelected: selectedSeat == 'B6',
                    isFaculty: _isFacultySeat('B6'),
                    userType: userType,
                    onTap: onSeatSelected,
                    onTakenTap: onTakenSeatTapped,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}