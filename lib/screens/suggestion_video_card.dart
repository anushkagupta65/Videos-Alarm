import 'package:flutter/material.dart';
import 'package:videos_alarm_app/components/app_style.dart';
import '../api_services/models/banner_list.dart';

class BannerVideosList extends StatefulWidget {
  const BannerVideosList({Key? key}) : super(key: key);

  @override
  State<BannerVideosList> createState() => _BannerVideosListState();
}

class _BannerVideosListState extends State<BannerVideosList> {
  BannerList bannerList = BannerList();
  bool isLoading = true;
  // _getAdsBanner(){
  //   client.bannerList().then((value){
  //     setState(() {
  //       bannerList = value;
  //       isLoading = false;
  //     });
  //   }).onError((error, stackTrace){
  //     logger.i(error);
  //     commToast("Some thing went wrong");
  //   });
  // }

  @override
  void initState() {
    // _getAdsBanner();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return isLoading == true
        ? SizedBox()
        : Container(
            height: 200,
            margin: const EdgeInsets.only(top: 16),
            child: PageView.builder(
              itemCount: bannerList.data!.length,
              onPageChanged: (i) {},
              scrollDirection: Axis.horizontal,
              itemBuilder: (context, idx) {
                var data = bannerList.data![idx];
                return InkWell(
                  onTap: () {
                    // Navigator.push(
                    //     context,
                    //     MaterialPageRoute(
                    //         builder: (context) => ViewVideo(
                    //               videoTitle: data.title.toString(),
                    //               description: data.description.toString(),
                    //               videoLink: data.link.toString(),
                    //               category: data..toString(),
                    //             ))
                    // );
                  },
                  child: Container(
                    margin: EdgeInsets.symmetric(horizontal: 2),
                    width: double.infinity,
                    height: 200,
                    decoration: BoxDecoration(
                        color: darkColor,
                        image: DecorationImage(
                            fit: BoxFit.fill,
                            image: NetworkImage(data.video_thumb.toString())),
                        borderRadius: BorderRadius.circular(10)),
                  ),
                );
              },
            ),
          );
  }
}
