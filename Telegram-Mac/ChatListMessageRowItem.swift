//
//  ChatListMessageRowItem.swift
//  Telegram-Mac
//
//  Created by keepcoder on 11/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import PostboxMac

class ChatListMessageRowItem: ChatListRowItem {

    init(_ initialSize:NSSize,  context: AccountContext, message: Message, query: String, renderedPeer:RenderedPeer) {
        
        
        super.init(initialSize, context: context, message: message, renderedPeer: RenderedPeer(message: message), highlightText: query)
    }
    
    override var stableId: AnyHashable {
        return message!.id
    }
}
