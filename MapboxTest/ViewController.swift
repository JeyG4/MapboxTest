//
//  ViewController.swift
//  MapboxTest
//
//  Created by Admin on 14.03.18.
//  Copyright © 2018 Evgeniy. All rights reserved.
//

import UIKit
import Mapbox

class ViewController: UIViewController, MGLMapViewDelegate  {
    
    var mapView: MGLMapView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        //Инициализируем карту, задаем начальную точку, добавляем ее на экран.
        let url = URL(string: "mapbox://styles/mapbox/streets-v10")
        mapView = MGLMapView(frame: view.bounds, styleURL: url)
        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        mapView.setCenter(CLLocationCoordinate2D(latitude: 55.753960, longitude: 37.620393), zoomLevel: 10, animated: false)
        view.addSubview(mapView)
        mapView.delegate = self
        //Добавляем для карты обработчик нажатия
        mapView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleMapTap(sender:))))
    }
    
    
    func mapView(_ mapView: MGLMapView, annotationCanShowCallout annotation: MGLAnnotation) -> Bool {
        return true
    }
    
    
    func mapView(_ mapView: MGLMapView, didFinishLoading style: MGLStyle) {
        //Считываем map.geojson
        let urlBar = Bundle.main.url(forResource: "map", withExtension: "geojson")!
        //Прописываем, чтобы названия на карте отображались в соответствии с языком установленным на устройстве
        style.localizesLabels = true
        do {
            let jsonData = try Data(contentsOf: urlBar)
            //Переводим их в модель
            let result = try JSONDecoder().decode(Collection.self, from: jsonData)
            let coll: Collection = result
            let features = parseJSONItems(collection: coll)
            //Добавляем на карту
            addItemsToMap(features: features)
        } catch { print("Error while parsing: \(error)") }
    }
    
    
    func parseJSONItems(collection: Collection) -> [MGLPointFeature] {
        //Созадем массив из точек, которые будем отображать, и выбираем из модели данные необходимые для последующего отображения, в нашем случае name и color
        var features = [MGLPointFeature]()
        for item in collection.features {
            let name = item.properties["name"]!
            let color = item.properties["color"]!
            let point = item.geometry.coordinates
            
            let coordinate = CLLocationCoordinate2D(latitude: Double(point[1]), longitude: Double(point[0]))
            let feature = MGLPointFeature()
            feature.coordinate = coordinate
            feature.title = name
            feature.attributes = [
                "color" : color,
                "name" : name
            ]
            features.append(feature)
        }
        return features
    }
    
    
    func addItemsToMap(features: [MGLPointFeature]) {
        //Добавляем данные на карту и настраиваем их отображение, в моем случае круги с внешней белой обводкой
        guard let style = mapView.style else { return }
        
        let source = MGLShapeSource(identifier: "mapPoints", features: features, options: nil)
        style.addSource(source)
        
        let colors = [
            "black": MGLStyleValue(rawValue: UIColor.black),
            "orange": MGLStyleValue(rawValue: UIColor.orange),
            "yellow": MGLStyleValue(rawValue: UIColor.yellow)
        ]
        
        let circles = MGLCircleStyleLayer(identifier: "mapPoints-circles", source: source)
        circles.circleColor = MGLSourceStyleFunction(interpolationMode: .identity,
                                                     stops: colors,
                                                     attributeName: "color",
                                                     options: nil)
        
        circles.circleRadius = MGLStyleValue(interpolationMode: .exponential,
                                             cameraStops: [2: MGLStyleValue(rawValue: 5),
                                                           7: MGLStyleValue(rawValue: 8)],
                                             options: nil)
        circles.circleStrokeWidth = MGLStyleValue(rawValue: 2)
        circles.circleStrokeColor = MGLStyleValue(rawValue: UIColor.white)
        
        style.addLayer(circles)
    }
    
    
    @objc func handleMapTap(sender: UITapGestureRecognizer) {
        //Обрабатываем нажатие на карту и вызываем аннотацию. Так как нажатие это конкретная точка, страхуемся от того что мы можем не правильно ее считать и задаем стандартную для Apple 44х44 область нажатия
        if sender.state == .ended {
            let layerIdentifiers: Set = ["mapPoints-circles"]
            
            let point = sender.location(in: sender.view!)
            for f in mapView.visibleFeatures(at: point, styleLayerIdentifiers:layerIdentifiers)
                where f is MGLPointFeature {
                    showCallout(feature: f as! MGLPointFeature)
                    return
            }
            
            let touchCoordinate = mapView.convert(point, toCoordinateFrom: sender.view!)
            let touchLocation = CLLocation(latitude: touchCoordinate.latitude, longitude: touchCoordinate.longitude)
            
            let touchRect = CGRect(origin: point, size: .zero).insetBy(dx: -22.0, dy: -22.0)
            let possibleFeatures = mapView.visibleFeatures(in: touchRect, styleLayerIdentifiers: Set(layerIdentifiers)).filter { $0 is MGLPointFeature }
            
            let closestFeatures = possibleFeatures.sorted(by: {
                return CLLocation(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude).distance(from: touchLocation) < CLLocation(latitude: $1.coordinate.latitude, longitude: $1.coordinate.longitude).distance(from: touchLocation)
            })
            if let f = closestFeatures.first {
                showCallout(feature: f as! MGLPointFeature)
                return
            }
            
            //Если нажали мимо - убираем аннотацию
            mapView.deselectAnnotation(mapView.selectedAnnotations.first, animated: true)
        }
    }
    
    
    func showCallout(feature: MGLPointFeature) {
        //Сам вызов аннотации
        let point = MGLPointFeature()
        point.title = feature.attributes["name"] as? String
        point.coordinate = feature.coordinate
        
        mapView.selectAnnotation(point, animated: true)
    }
    
    
    func mapView(_ mapView: MGLMapView, viewFor annotation: MGLAnnotation) -> MGLAnnotationView? {
        //Чтобы не появлялись стандартные маркеры аннотаций, переопределяем AnnotationView на свой
        guard annotation is MGLPointAnnotation else {
            return nil
        }
        
        let reuseIdentifier = "\(annotation.coordinate.longitude)"
        
        var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseIdentifier)
        
        if annotationView == nil {
            annotationView = MGLAnnotationView(reuseIdentifier: reuseIdentifier)
            annotationView!.frame = CGRect(x: 0, y: 0, width: 18, height: 18)
            annotationView!.backgroundColor = nil
        }
        
        return annotationView
    }
    
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    
}
