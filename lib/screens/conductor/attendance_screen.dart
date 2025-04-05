import 'package:flutter/material.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final searchController = TextEditingController();
  // mock bus stops
  String? selectedStatus;
  int currentStopIndex = 2;
  final List<String> busStops = [
    'Vijay Market',
    'Mahatma Gandhi Square',
    'Gandhi Market',
    'Piplani',
    'Ayodhya by pass',
    'Narela Jod',
    'Minal Residency (Gate No. 2)',
    'SIRT',
    'People\'s Mall',
    'BMHRC',
    'KAROND SQUARE',
    'RGPV',
    'Sanjeev Nagar Bus Stop',
    'Lalghati',
    'Chanchal Chouraha (Bairagarh)',
    'Fanda',
    'VIT CAMPUS (destination)',
  ];

  // Mock data for students:
  final List<Map<String, dynamic>> students = [
    {'name': 'Madhavi Patel', 'stop': 'Vijay Market', 'status': 'missed'},
    {'name': 'Viya Sharma', 'stop': 'Ayodhya by pass', 'status': 'present'},
    {'name': 'Qaisarali Sulaimani', 'stop': 'Ayodhya by pass', 'status': 'present'},
    {'name': 'Diksha Gupta', 'stop': 'Narela Jod', 'status': 'waiting'},
    {'name': 'Mehak Baid', 'stop': 'Narela Jod', 'status': 'waiting'},
    {'name': 'Anusha Gupta', 'stop': 'Narela Jod', 'status': 'waiting'},
    {'name': 'Akriti Tripati', 'stop': 'Minal Residency (Gate No. 2)', 'status': 'waiting'},
    {'name': 'Anushka Gupta', 'stop': 'Minal Residency (Gate No. 2)', 'status': 'waiting'},
    {'name': 'Abhijeet Singh', 'stop': 'KAROND SQUARE', 'status': 'waiting'},
    {'name': 'Poonam Kumari', 'stop': 'KAROND SQUARE', 'status': 'waiting'},
    {'name': 'Diya Jain', 'stop': 'RGPV', 'status': 'waiting'},
    {'name': 'Muskaan Roy', 'stop': 'Lalghati', 'status': 'waiting'},
    {'name': 'Suhani Kapoor', 'stop': 'Lalghati', 'status': 'waiting'},
    {'name': 'Swara Nahata', 'stop': 'Lalghati', 'status': 'waiting'},
    {'name': 'Meera Sharma', 'stop': 'Lalghati', 'status': 'waiting'},
  ];

  int get totalStudents => students.length;
  int get presentStudents => students.where((s) => s['status'] == 'present').length;
  int get absentStudents => students.where((s) => s['status'] == 'absent').length;
  int get waitingStudents => students.where((s) => s['status'] == 'waiting').length;
  int get missedStudents => students.where((s) => s['status'] == 'missed').length;

  Color getStatusColor(String status) {
    switch (status) {
      case 'present': return Colors.green.shade100;
      case 'absent': return Colors.red.shade100;
      case 'waiting': return Colors.orange.shade100;
      case 'missed': return Colors.purple.shade100;
      default: return Colors.grey.shade200;
    }
  }

  int getStopIndex(String stop) {
    return busStops.indexOf(stop);
  }

  // Update student statuses when moving to next stop
  void updateStudentStatuses() {
    for (var student in students) {
      final stopIndex = getStopIndex(student['stop'] as String);

      // if we just passed their stop and they're still waiting mark as missed
      if (stopIndex == currentStopIndex - 1 && student['status'] == 'waiting') {
        student['status'] = 'missed';
      }
    }
  }

  // mark all remaining missed students as absent at the end of the route
  void markRemainingAsAbsent() {
    for (var student in students) {
      if (student['status'] == 'missed') {
        student['status'] = 'absent';
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('All missed students marked as ABSENT'),
        backgroundColor: Colors.red,
      ),
    );
  }

  List<Map<String, dynamic>> getSortedStudents() {
    final List<Map<String, dynamic>> sortedList = [...students];

    sortedList.sort((a, b) {
      final statusA = a['status'] as String;
      final statusB = b['status'] as String;

      // priority map for statuses
      final statusPriority = {
        'waiting': 0,
        'missed': 1,
        'present': 2,
        'absent': 3,
      };

      // sort by status priority
      final priorityA = statusPriority[statusA] ?? 4;
      final priorityB = statusPriority[statusB] ?? 4;

      if (priorityA != priorityB) {
        return priorityA - priorityB;
      }

      // if both are waiting sort by upcoming stop first
      if (statusA == 'waiting') {
        final stopIndexA = getStopIndex(a['stop'] as String);
        final stopIndexB = getStopIndex(b['stop'] as String);

        // sort by proximity to current bus location
        if (stopIndexA >= currentStopIndex && stopIndexB >= currentStopIndex) {
          return stopIndexA - stopIndexB;
        } else if (stopIndexA >= currentStopIndex) {
          return -1; // A comes first
        } else if (stopIndexB >= currentStopIndex) {
          return 1; // B comes first
        }
      }

      // if both are missed sort by name
      if (statusA == 'missed') {
        return (a['name'] as String).compareTo(b['name'] as String);
      }

      // for other equal statuses keep original order
      return 0;
    });

    return sortedList;
  }
  // render UI
  @override
  Widget build(BuildContext context) {
    final sortedStudents = getSortedStudents();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        actions: [
          // current location control
          IconButton(
            icon: const Icon(Icons.location_on),
            onPressed: () {
              _selectCurrentLocation(context);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // current location indicator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                const Icon(Icons.location_on, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Current Location: ${busStops[currentStopIndex]}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      if (currentStopIndex < busStops.length - 1) {
                        currentStopIndex++;
                        updateStudentStatuses();
                      } else if (currentStopIndex == busStops.length - 1) {
                        // at the last stop mark all missed students as absent
                        _showEndOfRouteDialog();
                      }
                    });
                  },
                  child: const Text('Next Stop →'),
                ),
              ],
            ),
          ),

          // statistics cards with tap functionality
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatCard('Total', totalStudents.toString(), Colors.grey.shade200, null),
                  _buildStatCard('Present', presentStudents.toString(),
                      selectedStatus == 'present' ? Colors.green.shade100 : Colors.grey.shade200, 'present'),
                  _buildStatCard('Missed', missedStudents.toString(),
                      selectedStatus == 'missed' ? Colors.purple.shade100 : Colors.grey.shade200, 'missed'),
                  _buildStatCard('Absent', absentStudents.toString(),
                      selectedStatus == 'absent' ? Colors.red.shade100 : Colors.grey.shade200, 'absent'),
                  _buildStatCard('Waiting', waitingStudents.toString(),
                      selectedStatus == 'waiting' ? Colors.orange.shade100 : Colors.grey.shade200, 'waiting'),
                ],
              ),
            ),
          ),

          // active filter indicator
          if (selectedStatus != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Text(
                    'Showing: ${selectedStatus!.toUpperCase()}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        selectedStatus = null;
                      });
                    },
                    child: const Text('Clear Filter'),
                  ),
                ],
              ),
            ),

          // search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Search',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30.0),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade200,
                contentPadding: const EdgeInsets.symmetric(vertical: 0.0),
              ),
              onChanged: (value) {
                // trigger rebuild when search text changes
                setState(() {});
              },
            ),
          ),

          // stud list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              itemCount: sortedStudents.length,
              itemBuilder: (context, index) {
                final student = sortedStudents[index];

                // apply status filter if selected
                if (selectedStatus != null && student['status'] != selectedStatus) {
                  return const SizedBox.shrink();
                }

                // apply search filter if there's text in the search field
                if (searchController.text.isNotEmpty &&
                    !student['name'].toString().toLowerCase().contains(
                      searchController.text.toLowerCase(),
                    ) &&
                    !student['stop'].toString().toLowerCase().contains(
                      searchController.text.toLowerCase(),
                    )) {
                  return const SizedBox.shrink();
                }

                return _buildStudentCard(student);
              },
            ),
          ),
        ],
      ),
    );
  }
  // show a dialog at the last stop to mark missed as absent
  void _showEndOfRouteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End of Route'),
        content: const Text('You\'ve reached the last stop. Would you like to mark all missed students as absent?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Not Now'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                markRemainingAsAbsent();
              });
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(
              backgroundColor: Colors.red.shade100,
            ),
            child: const Text('Mark All Absent'),
          ),
        ],
      ),
    );
  }
  // show a dialog to select current location
  void _selectCurrentLocation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Current Location'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: busStops.length,
            itemBuilder: (context, index) {
              return ListTile(
                title: Text(busStops[index]),
                selected: index == currentStopIndex,
                onTap: () {
                  setState(() {
                    // If we're moving backward, don't change statuses
                    // If moving forward, update statuses of stops we pass
                    if (index > currentStopIndex) {
                      for (int i = currentStopIndex + 1; i <= index; i++) {
                        // Update for each stop we pass
                        currentStopIndex = i - 1;
                        updateStudentStatuses();
                      }
                    }
                    currentStopIndex = index;
                  });
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
  // build a card for each status
  Widget _buildStatCard(String title, String count, Color color, String? status) {
    return GestureDetector(
      onTap: () {
        setState(() {
          // if tapping the same status again clear the filter
          if (selectedStatus == status) {
            selectedStatus = null;
          } else {
            selectedStatus = status;
          }
        });
      },
      child: Container(
        width: 80,
        height: 80,
        margin: const EdgeInsets.symmetric(horizontal: 4.0),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8.0),
          border: selectedStatus == status
              ? Border.all(color: Colors.blue, width: 2)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              count,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
  // build a card for each student
  Widget _buildStudentCard(Map<String, dynamic> student) {
    final status = student['status'] as String;
    final stopName = student['stop'] as String;
    final stopIndex = busStops.indexOf(stopName);

    // next stop indicator
    final bool isNextStop = (stopIndex == currentStopIndex + 1) && status == 'waiting';

    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      elevation: 0,
      color: getStatusColor(status),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
        side: isNextStop ? BorderSide(color: Colors.blue, width: 2) : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            // stud avatar
            CircleAvatar(
              radius: 25,
              backgroundColor: Colors.grey.shade400,
              child: const Icon(
                Icons.person,
                color: Colors.white,
                size: 30,
              ),
            ),
            const SizedBox(width: 16),

            // stud details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Name: ${student['name']}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Stop: ${student['stop']}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                      if (isNextStop)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'NEXT STOP',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: status == 'present' ? Colors.green.shade700 :
                        status == 'absent' ? Colors.red.shade700 :
                        status == 'missed' ? Colors.purple.shade700 :
                        Colors.orange.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // QR code icon
            GestureDetector(
              onTap: () {
                // open camera to scan ID/bus pass
                _openScanner(context, student);
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Icon(
                  Icons.qr_code_scanner,
                  color: Colors.grey.shade500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openScanner(BuildContext context, Map<String, dynamic> student) {
    // mock camera interface with scanner
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Scan Student ID/Bus Pass'),
        content: SizedBox(
          height: 300,
          child: Column(
            children: [
              Expanded(
                child: Container(
                  color: Colors.black,
                  child: Center(
                    child: Icon(
                      Icons.qr_code_scanner,
                      color: Colors.white.withOpacity(0.5),
                      size: 100,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Position the QR code within the frame to scan',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              // Process the scan result
              _processScanResult(student);
              Navigator.pop(context);
            },
            child: const Text('Mock Scan'),
          ),
        ],
      ),
    );
  }
  // process the scan result and update student status
  void _processScanResult(Map<String, dynamic> student) {
    setState(() {
      final stopIndex = getStopIndex(student['stop'] as String);
      final status = student['status'] as String;

      // always allow marking as present for waiting students
      if (status == 'waiting') {
        student['status'] = 'present';
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Student marked PRESENT'),
            backgroundColor: Colors.green,
          ),
        );
        return;
      }

      // allow missed students to be marked present
      if (status == 'missed') {
        student['status'] = 'present';
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Student found and marked PRESENT'),
            backgroundColor: Colors.green,
          ),
        );
        return;
      }

      // show info message for already present or absent students
      final statusMessage = status == 'present' ? 'already marked PRESENT' : 'marked ABSENT';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Student is $statusMessage'),
          backgroundColor: status == 'present' ? Colors.blue : Colors.red,
        ),
      );
    });
  }
}