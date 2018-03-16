//
//  Model.swift
//  MapboxTest
//
//  Created by Admin on 14.03.18.
//  Copyright © 2018 Evgeniy. All rights reserved.
//

import UIKit

//Модель

struct Collection : Decodable {
    let type : String
    let features : [Feature]
}

struct Feature : Decodable {
    let type : String
    let properties : [String : String]
    let geometry : Geometry
}

struct Geometry : Decodable {
    let type : String
    let coordinates : [Double]
}

