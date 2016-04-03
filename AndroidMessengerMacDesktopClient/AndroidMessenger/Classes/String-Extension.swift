//
//  String-Extension.swift
//  AndroidMessenger
//
//  Created by Kalyan Vishnubhatla on 4/2/16.
//  Copyright © 2016 Kalyan Vishnubhatla. All rights reserved.
//

import Foundation

extension String {
    func isValidIPv4() -> Bool {
        var throwaway: in_addr? = nil
        let success = inet_pton(AF_INET, self, &throwaway);
        return success == 1
    }
    
    func isValidIPv6() -> Bool {
        var throwaway: in_addr? = nil
        let success = inet_pton(AF_INET6, self, &throwaway);
        return success == 1
    }
    
    func isValidIPAddress() -> Bool {
        return self.isValidIPv4() || self.isValidIPv6()
    }

}