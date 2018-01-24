//
//  ViewController.swift
//  MapLocation
//
//  Created by 曾政桦 on 2018/1/24.
//  Copyright © 2018年 隐贞. All rights reserved.
//

import UIKit
import CoreLocation
import MapKit

class ViewController: UIViewController {
    
    fileprivate let annotationId = "PIN_ANNOTATION"
    
    @IBOutlet weak var searchBar: UISearchBar! {
        didSet {
            searchBar.backgroundColor = UIColor.clear
        }
    }
    
    @IBOutlet weak var titleLabel: UILabel! {
        didSet {
            titleLabel.text = nil
        }
    }
    
    @IBOutlet weak var mapView: MKMapView! {
        didSet {
            mapView.mapType = .standard
            mapView.showsUserLocation = true
            mapView.showsPointsOfInterest = true
            mapView.setUserTrackingMode(.followWithHeading, animated: true)
            if #available(iOS 11.0, *) {
                mapView.register(MKPinAnnotationView.self, forAnnotationViewWithReuseIdentifier: annotationId)
            } else {
                /// 其它版本的系统需要自行实现
            }
        }
    }
    
    @IBOutlet weak var tableHeadView: UIView!
    
    @IBOutlet weak var tableView: UITableView!
    
    
    // 管理者
    fileprivate var locationManager = CLLocationManager()
    
    // 数据
    fileprivate var searchResults = [CLPlacemark]()
    fileprivate var currentLocation: CLPlacemark?
    fileprivate var destiLocation: CLPlacemark?
    fileprivate var lastAnnotation: MKPointAnnotation?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        userLocationInit()
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        view.endEditing(true)
    }
}


// MARK: - 处理逻辑
extension ViewController {
    
    /// 用户当前位置的初始化，其实可要可不要，因为 MapView 自带有
    func userLocationInit() {
        locationManager.delegate = self
        if CLLocationManager.locationServicesEnabled() {
            locationManager.requestWhenInUseAuthorization()
        } else {
            print("Location Not In Use")
        }
    }
    
    /// 结构化地址信息
    func locationText(mark: CLPlacemark) -> String {
        var locationText = ""
        
        if let city = mark.locality {
            locationText = locationText.appending(city)
        }
        
        if let subCity = mark.subLocality {
            locationText = locationText.appending(subCity)
        }
        
        if let detail = mark.name {
            if detail.contains(locationText) {
                locationText = detail
            } else {
                locationText = locationText.appending(detail)
            }
        }
        
        return locationText
    }
    
    /// 通过关键词进行地理位置信息搜索
    /// 1. 如果当前进行其它城市的检索需要输入完整的信息，默认填充当前用户所在的城市位置
    func locationSearch(text: String) {
        
        // 如果当前检索的内容没有xx市，则添加当前用户市所在信息
        var cityText = text
        if let city = currentLocation?.locality {
            if !(text.contains(city)), !(text.contains("市")) {
                cityText = city + text
            }
        }
        
        // 进行系统关键字检索信息
        CLGeocoder().geocodeAddressString(cityText) { (placeMarks, error) in
            if error == nil {
                if let arr = placeMarks {
                    self.dealSearchResults(markPlaces: arr)
                }
            } else {
                print(error?.localizedDescription ?? "Error")
            }
        }
    }
    
    /// 通过地理编码进行反编译识别
    func locationReverseSearch(location: CLLocation) {
        CLGeocoder().reverseGeocodeLocation(location, completionHandler: { (placeMarks, error) in
            if error == nil {
                guard let marks = placeMarks else { return }
                self.dealSearchResults(markPlaces: marks)
            } else {
                print(error?.localizedDescription ?? "error reverse Geocode Location")
            }
        })
    }
    
    /// 用于处理搜索结果
    /// 1. 清除之前搜索到的结果
    /// 2. 选择第一个匹配度较高的信息给提示栏
    /// 3. 将额外的选项信息交给tableView
    func dealSearchResults(markPlaces: [CLPlacemark]) {
        if let mark = markPlaces.first {
            titleLabel.text = locationText(mark: mark)
        }
        searchResults.removeAll()
        searchResults.append(contentsOf: markPlaces)
        tableView.reloadData()
    }
    
    /// 添加大头针
    func addAnnotaionToMapView(mark: CLPlacemark) {
        
        // 清除之前的大图标
        if lastAnnotation != nil {
            mapView.removeAnnotation(lastAnnotation!)
        }
        
        let pointAnnotation = MKPointAnnotation()
        pointAnnotation.coordinate = (mark.location?.coordinate)!
        pointAnnotation.title = mark.name
        pointAnnotation.subtitle = mark.locality
        mapView.addAnnotation(pointAnnotation)
        lastAnnotation = pointAnnotation
        
        titleLabel.text = locationText(mark: mark)
        
        //设置地图显示的范围，地图显示范围越小，细节越清楚
        let span = MKCoordinateSpan(latitudeDelta:0.005, longitudeDelta:0.005)
        //创建MKCoordinateRegion对象，该对象代表了地图的显示中心和显示范围。
        let region = MKCoordinateRegion(center: (mark.location?.coordinate)!, span: span)
        //设置当前地图的显示中心和显示范围
        self.mapView.setRegion(region, animated:true)
    }
}

// MARK: - 搜索栏代理方法
extension ViewController: UISearchBarDelegate {
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        guard let text = searchBar.text else { return }
        searchBar.resignFirstResponder()
        locationSearch(text: text)
    }
}

// MARK: - 系统地图代理方法
extension ViewController: MKMapViewDelegate {
    func mapViewDidFailLoadingMap(_ mapView: MKMapView, withError error: Error) {
        print("map view did fail")
    }
    
    /// 大头针的添加方法，不过注意只有11.0注册方法的问题
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        let anView = mapView.dequeueReusableAnnotationView(withIdentifier: annotationId, for: annotation)
        anView.isDraggable = true
        anView.calloutOffset = CGPoint(x: 0, y: 0)
        return anView
    }
    
    /// 大头针移动代理
    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, didChange newState: MKAnnotationViewDragState, fromOldState oldState: MKAnnotationViewDragState) {
        if newState == .ending {
            guard let coordinate = view.annotation?.coordinate else { return }
            let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            locationReverseSearch(location: location)
        }
    }
}

// MARK: - 系统定位代理方法
extension ViewController: CLLocationManagerDelegate {
    
    // 用户进入视图进行定位, 通常来说定位当前的地理位置系只返回一个精确度较高结果
    // 将当前的用户的定位信息进行记录
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse {
            guard let location = manager.location else { return }
            CLGeocoder().reverseGeocodeLocation(location, completionHandler: { (plas, error) in
                if error == nil {
                    guard let currentLocation = plas?.first else { return }
                    self.destiLocation = currentLocation
                    self.currentLocation = currentLocation
                    self.titleLabel.text = self.locationText(mark: currentLocation)
                    self.addAnnotaionToMapView(mark: currentLocation)
                    
                    // 用户首次定位成功后就停止定位操作
                    manager.stopUpdatingLocation()
                } else {
                    print(error?.localizedDescription ?? "")
                }
            })
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("location Error: \(error.localizedDescription)")
    }
}

// MARK: - 列表栏代理事件及方法
extension ViewController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return searchResults.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: MapCell.cellId, for: indexPath) as! MapCell
        let model = searchResults[indexPath.row]
        cell.locationLabel.text = locationText(mark: model)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        destiLocation = searchResults[indexPath.row]
        addAnnotaionToMapView(mark: destiLocation!)
    }
}
