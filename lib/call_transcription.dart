import 'dart:async';
import 'dart:io';

import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path_provider/path_provider.dart';

class CallTranscription extends StatefulWidget {
  const CallTranscription({super.key});

  @override
  State<CallTranscription> createState() => _CallTranscriptionState();
}

class _CallTranscriptionState extends State<CallTranscription>
    with SingleTickerProviderStateMixin {
  late PlayerController _playerController;
  late TabController _tabController;
  final ValueNotifier<bool> _isLoading = ValueNotifier(true);
  final ValueNotifier<String> _timeElapsed = ValueNotifier('00:00:00');
  final ValueNotifier<String> _totalTime = ValueNotifier('00:00:00');
  final ValueNotifier<double> _playbackSpeed = ValueNotifier(1.0);
  final ValueNotifier<bool> _isPlaying = ValueNotifier(false);
  static const Color _blueColor = Color(0XFF1F62FF);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _initializeAudio();
  }

  Future<void> _initializeAudio() async {
    _playerController = PlayerController()
      ..updateFrequency = UpdateFrequency.high;
    final audioPath = await _loadAudioFile();
    await _playerController.preparePlayer(
      path: audioPath,
      shouldExtractWaveform: true,
      noOfSamples: 100,
      volume: 1.0,
    );
    _isLoading.value = false;
    _updateTotalTime();
    _playerController.onCurrentDurationChanged.listen(
        (duration) => _timeElapsed.value = _formatDuration(duration ~/ 1000));
    _playerController.onPlayerStateChanged
        .listen((state) => _isPlaying.value = state == PlayerState.playing);
  }

  Future<String> _loadAudioFile() async {
    final tempDir = await getTemporaryDirectory();
    final tempPath = '${tempDir.path}/demo.mp3';
    final audioFile = File(tempPath);
    if (!await audioFile.exists()) {
      final audioBytes = await rootBundle.load('assets/demo.mp3');
      await audioFile.writeAsBytes(audioBytes.buffer.asUint8List());
    }
    return tempPath;
  }

  void _togglePlayPause() => _isPlaying.value
      ? _playerController.pausePlayer()
      : _playerController.startPlayer();

  void _updateTotalTime() =>
      _totalTime.value = _formatDuration(_playerController.maxDuration ~/ 1000);

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  void _changeSpeed() {
    _playbackSpeed.value = _playbackSpeed.value == 1.0
        ? 1.5
        : (_playbackSpeed.value == 1.5 ? 2.0 : 1.0);
    _playerController.setRate(_playbackSpeed.value);
  }

  Future<void> _seek(int seconds) async {
    final currentPos =
        await _playerController.getDuration(DurationType.current);
    _playerController.seekTo(currentPos + seconds * 1000);
  }

  @override
  void dispose() {
    _playerController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: ValueListenableBuilder<bool>(
        valueListenable: _isLoading,
        builder: (context, isLoading, _) => isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  const SizedBox(height: 16),
                  _buildWaveform(size),
                  const Spacer(),
                  _buildControlPanel(),
                ],
              ),
      ),
    );
  }

  AppBar _buildAppBar() => AppBar(
        leading: const Icon(Icons.arrow_back_rounded, color: _blueColor),
        title: const Text('Call Transcription',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
              onPressed: () {},
              icon: const Icon(Icons.more_vert_rounded, color: _blueColor))
        ],
        backgroundColor: Colors.transparent,
        bottom: TabBar(
          controller: _tabController,
          dividerHeight: 0.5,
          indicatorColor: _blueColor,
          labelColor: _blueColor,
          labelPadding: EdgeInsets.zero,
          unselectedLabelColor: const Color(0XFF4B5563),
          splashFactory: NoSplash.splashFactory,
          tabs: ['Overview', 'Transcripts', 'Comments', 'Call Intelligence']
              .map((e) => Tab(text: e))
              .toList(),
        ),
      );

  Widget _buildWaveform(Size size) => Stack(
        alignment: Alignment.topCenter,
        children: [
          AudioFileWaveforms(
            size: Size(size.width, size.height * 84 / 328),
            playerController: _playerController,
            enableSeekGesture: true,
            waveformType: WaveformType.long,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
                color: const Color(0XFFF7F8FB),
                borderRadius: BorderRadius.circular(8)),
            playerWaveStyle: PlayerWaveStyle(
              liveWaveColor: _blueColor,
              fixedWaveColor: _blueColor.withOpacity(0.31),
              scaleFactor: size.height * 2,
              waveThickness: 4,
              spacing: 8,
              showBottom: false,
              waveCap: StrokeCap.square,
              seekLineColor: const Color(0XFF07090F),
              seekLineThickness: 2,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
                color: const Color(0XFF07090F),
                borderRadius: BorderRadius.circular(4)),
            child: ValueListenableBuilder<String>(
              valueListenable: _timeElapsed,
              builder: (_, timeElapsed, __) => Text(timeElapsed,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
                color: Colors.white, height: (size.height * 84 / 328) / 2 - 6),
          ),
        ],
      );

  Widget _buildControlPanel() => Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        color: const Color(0XFFF7F8FB),
        child: Column(
          children: [
            ValueListenableBuilder<String>(
              valueListenable: _timeElapsed,
              builder: (_, timeElapsed, __) =>
                  Text('$timeElapsed / ${_totalTime.value}'),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ValueListenableBuilder<double>(
                  valueListenable: _playbackSpeed,
                  builder: (_, speed, __) => IconButton(
                    onPressed: _changeSpeed,
                    icon: Text('${speed % 1 == 0 ? speed.toInt() : speed}x',
                        style: const TextStyle(
                            color: Color(0XFF6B7280),
                            fontWeight: FontWeight.w400,
                            fontSize: 20)),
                  ),
                ),
                IconButton(
                    onPressed: () => _seek(-10),
                    icon: SvgPicture.asset('assets/ic_seek_backward_10.svg')),
                ValueListenableBuilder<bool>(
                  valueListenable: _isPlaying,
                  builder: (_, isPlaying, __) => IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: _blueColor,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.all(10),
                    ),
                    onPressed: _togglePlayPause,
                    icon: SvgPicture.asset(isPlaying
                        ? 'assets/ic_pause.svg'
                        : 'assets/ic_play.svg'),
                  ),
                ),
                IconButton(
                    onPressed: () => _seek(10),
                    icon: SvgPicture.asset('assets/ic_seek_forward_10.svg')),
                IconButton(
                    onPressed: () {},
                    icon: SvgPicture.asset('assets/ic_expand.svg')),
              ],
            ),
          ],
        ),
      );
}
