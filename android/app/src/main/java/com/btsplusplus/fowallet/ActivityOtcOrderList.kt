package com.btsplusplus.fowallet

import android.support.v7.app.AppCompatActivity
import android.os.Bundle
import android.support.design.widget.TabLayout
import android.support.v4.app.Fragment
import android.support.v4.view.ViewPager
import android.view.animation.OvershootInterpolator
import android.widget.LinearLayout
import bitshares.forEach
import kotlinx.android.synthetic.main.activity_otc_merchant_list.*
import kotlinx.android.synthetic.main.activity_otc_order_list.*
import org.json.JSONArray
import org.json.JSONObject
import java.lang.reflect.Field

class ActivityOtcOrderList : BtsppActivity() {

    private val fragmens: ArrayList<Fragment> = ArrayList()
    private var tablayout: TabLayout? = null
    private var view_pager: ViewPager? = null

    private lateinit var _data: JSONArray

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        //  设置自动布局
        setAutoLayoutContentView(R.layout.activity_otc_order_list)
        //  设置全屏(隐藏状态栏和虚拟导航栏)
        setFullScreen()

        //  返回
        layout_back_from_otc_merchant_order_list.setOnClickListener { finish() }

        // 设置 tablelayout 和 view_pager
        tablayout = tablayout_of_otc_order_list
        view_pager = view_pager_of_otc_order_list

        getData()

        // 添加 fargments
        setFragments()

        // 设置 viewPager 并配置滚动速度
        setViewPager()

        // 监听 tab 并设置选中 item
        setTabListener()

    }

    private fun getData(){
        _data = JSONArray().apply {
            for (i in 0 until 10) {
                put(JSONObject().apply {
                    put("order_type", 1)
                    put("asset_name", "CNY")
                    put("time", "2019-12-12T12:12")
                    put("quantity", 7.76)
                    put("price", 7.92)
                    put("legal_symbol", "¥")
                    put("merchant_name", "吉祥承兑")
                })
                put(JSONObject().apply {
                    put("order_type", 2)
                    put("asset_name", "GDEX.USDT")
                    put("time", "2019-12-12T12:12")
                    put("quantity", 17.76)
                    put("price", 17.92)
                    put("legal_symbol", "$")
                    put("merchant_name", "XX承兑")
                })
            }
        }
    }


    private fun setViewPager() {
        view_pager!!.adapter = ViewPagerAdapter(super.getSupportFragmentManager(), fragmens)
        val f: Field = ViewPager::class.java.getDeclaredField("mScroller")
        f.isAccessible = true
        val vpc: ViewPagerScroller = ViewPagerScroller(view_pager!!.context, OvershootInterpolator(0.6f))
        f.set(view_pager, vpc)
        vpc.duration = 700

        view_pager!!.setOnPageChangeListener(object : ViewPager.OnPageChangeListener {
            override fun onPageScrollStateChanged(state: Int) {
            }

            override fun onPageScrolled(position: Int, positionOffset: Float, positionOffsetPixels: Int) {
            }

            override fun onPageSelected(position: Int) {
                println(position)
                tablayout!!.getTabAt(position)!!.select()
            }
        })
    }

    private fun setFragments() {
        // todo data 分类筛选
        fragmens.add(FragmentOtcOrderList().initialize(_data))
        fragmens.add(FragmentOtcOrderList().initialize(_data))
        fragmens.add(FragmentOtcOrderList().initialize(_data))
    }

    private fun setTabListener() {
        tablayout!!.setOnTabSelectedListener(object : TabLayout.OnTabSelectedListener {
            override fun onTabSelected(tab: TabLayout.Tab) {
                view_pager!!.setCurrentItem(tab.position, true)
            }

            override fun onTabUnselected(tab: TabLayout.Tab) {
                //tab未被选择的时候回调
            }

            override fun onTabReselected(tab: TabLayout.Tab) {
                //tab重新选择的时候回调
            }
        })
    }



}
