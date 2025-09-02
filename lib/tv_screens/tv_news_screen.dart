import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:videos_alarm_app/api_services/models/news_list.dart';
import 'package:videos_alarm_app/components/blogdetailspage.dart';
import '../components/check_internet.dart';
import '../components/loader.dart';
import '../components/network_error_wiget.dart';
import 'package:intl/intl.dart';

class TVNewsScreen extends StatefulWidget {
  const TVNewsScreen({super.key});

  @override
  State<TVNewsScreen> createState() => _TVNewsScreenState();
}

class _TVNewsScreenState extends State<TVNewsScreen> {
  NewsList newsList = NewsList();
  bool isLoading = true;
  bool isNetwork = true;

  final ScrollController _scrollController = ScrollController();
  List<List<FocusNode>> _focusNodes = [];
  List<List<GlobalKey>> _itemKeys = [];

  static const int _crossAxisCount = 3;

  @override
  void initState() {
    super.initState();
    _checkNetWork();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _disposeFocusNodes();
    super.dispose();
  }

  Future<void> _getNews() async {
    if (!await isNetworkAvailable()) {
      setState(() => isNetwork = false);
      return;
    }

    setState(() => isLoading = true);

    try {
      QuerySnapshot querySnapshot =
          await FirebaseFirestore.instance.collection('blogs').get();

      List<Articles> articles = querySnapshot.docs.map((doc) {
        var data = doc.data() as Map<String, dynamic>;
        return Articles(
          source:
              Sources(id: data['source']['id'], name: data['source']['name']),
          author: data['author'],
          title: data['title'],
          description: data['description'],
          url: data['url'],
          urlToImage: data['urlToImage'],
          publishedAt: data['publishedAt'],
          content: data['content'],
        );
      }).toList();

      if (mounted) {
        setState(() {
          newsList = NewsList(
              status: 'success',
              totalResults: articles.length,
              articles: articles);
          isLoading = false;
          _initializeFocusNodes();
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _checkNetWork() async {
    if (!await isNetworkAvailable()) {
      if (mounted) setState(() => isNetwork = false);
    } else {
      _getNews();
    }
  }

  void _initializeFocusNodes() {
    _disposeFocusNodes();
    final articles = newsList.articles ?? [];

    if (articles.isNotEmpty) {
      final int gridRowCount = (articles.length / _crossAxisCount).ceil();
      for (int i = 0; i < gridRowCount; i++) {
        final int start = i * _crossAxisCount;
        final int end = (start + _crossAxisCount).clamp(0, articles.length);
        final int itemsInRow = end - start;

        _focusNodes.add(List.generate(itemsInRow,
            (j) => FocusNode(debugLabel: 'NewsCard Row $i Col $j')));
        _itemKeys.add(List.generate(itemsInRow, (j) => GlobalKey()));
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _focusNodes.isNotEmpty && _focusNodes.first.isNotEmpty) {
        _focusNodes.first.first.requestFocus();
      }
    });
  }

  void _disposeFocusNodes() {
    for (var row in _focusNodes) {
      for (var node in row) {
        node.dispose();
      }
    }
    _focusNodes = [];
    _itemKeys = [];
  }

  void _scrollToItem(int row, int col) {
    if (row < 0 ||
        row >= _itemKeys.length ||
        col < 0 ||
        col >= _itemKeys[row].length) {
      return;
    }
    final key = _itemKeys[row][col];
    if (key.currentContext != null) {
      Scrollable.ensureVisible(
        key.currentContext!,
        duration: const Duration(milliseconds: 300),
        alignment: 0.5,
        curve: Curves.easeInOut,
      );
    }
  }

  KeyEventResult _handleCardKeyEvent(
      KeyEvent event, int row, int col, Articles article) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.select ||
        event.logicalKey == LogicalKeyboardKey.enter) {
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => BlogDetailsScreen(article: article)));
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (row > 0) {
        int prevRow = row - 1;
        int prevCol = col.clamp(0, _focusNodes[prevRow].length - 1);
        _focusNodes[prevRow][prevCol].requestFocus();
        _scrollToItem(prevRow, prevCol);
        return KeyEventResult.handled;
      }
    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      if (row < _focusNodes.length - 1) {
        int nextRow = row + 1;
        int nextCol = col.clamp(0, _focusNodes[nextRow].length - 1);
        _focusNodes[nextRow][nextCol].requestFocus();
        _scrollToItem(nextRow, nextCol);
        return KeyEventResult.handled;
      }
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      if (col > 0) {
        _focusNodes[row][col - 1].requestFocus();
        _scrollToItem(row, col - 1);
        return KeyEventResult.handled;
      }
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      if (col < _focusNodes[row].length - 1) {
        _focusNodes[row][col + 1].requestFocus();
        _scrollToItem(row, col + 1);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    if (!isNetwork) {
      return networkError();
    }
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 48.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: isLoading
                  ? Center(child: LoaderWidget())
                  : (newsList.articles?.isEmpty ?? true)
                      ? const Center(
                          child: Text(
                            "No news found.",
                            style: TextStyle(color: Colors.white, fontSize: 18),
                          ),
                        )
                      : GridView.builder(
                          controller: _scrollController,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: _crossAxisCount,
                            childAspectRatio: 4 / 3,
                            crossAxisSpacing: 28,
                            mainAxisSpacing: 28,
                          ),
                          itemCount: newsList.articles!.length,
                          itemBuilder: (context, index) {
                            final article = newsList.articles![index];
                            final row = index ~/ _crossAxisCount;
                            final col = index % _crossAxisCount;
                            return _TVNewsCard(
                              key: _itemKeys[row][col],
                              article: article,
                              focusNode: _focusNodes[row][col],
                              onKeyEvent: (node, event) =>
                                  _handleCardKeyEvent(event, row, col, article),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TVNewsCard extends StatefulWidget {
  final Articles article;
  final FocusNode focusNode;
  final FocusOnKeyEventCallback onKeyEvent;

  const _TVNewsCard({
    Key? key,
    required this.article,
    required this.focusNode,
    required this.onKeyEvent,
  }) : super(key: key);

  @override
  State<_TVNewsCard> createState() => __TVNewsCardState();
}

class __TVNewsCardState extends State<_TVNewsCard> {
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChange);
    _isFocused = widget.focusNode.hasFocus;
  }

  @override
  void didUpdateWidget(covariant _TVNewsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusNode != oldWidget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocusChange);
      widget.focusNode.addListener(_onFocusChange);
      _isFocused = widget.focusNode.hasFocus;
    }
  }

  void _onFocusChange() {
    if (mounted) {
      setState(() => _isFocused = widget.focusNode.hasFocus);
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cardBorder = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: _isFocused
          ? const BorderSide(color: Colors.blueAccent, width: 2.0)
          : BorderSide.none,
    );

    return Focus(
      focusNode: widget.focusNode,
      onKeyEvent: widget.onKeyEvent,
      canRequestFocus: true,
      skipTraversal: false,
      child: GestureDetector(
        onTap: () {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => BlogDetailsScreen(article: widget.article)));
        },
        child: AnimatedScale(
          scale: _isFocused ? 1.05 : 1.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Card(
              elevation: _isFocused ? 10 : 2,
              shape: cardBorder,
              clipBehavior: Clip.antiAlias,
              color: const Color(0xFF212121),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 5,
                    child: Image.network(
                      widget.article.urlToImage.toString(),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const Center(
                              child: Icon(Icons.broken_image,
                                  color: Colors.grey, size: 48)),
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(
                            child: CircularProgressIndicator(strokeWidth: 2));
                      },
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.article.title.toString(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                          ),
                          Text(
                            DateFormat('MMM d, yyyy').format(DateTime.parse(
                                widget.article.publishedAt.toString())),
                            style:
                                TextStyle(color: Colors.grey[400], fontSize: 8),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
