/*
 * Str2AttrStrXibLocInfo.swift
 * XibLoc
 *
 * Created by François Lamboley on 4/16/18.
 * Copyright © 2018 happn. All rights reserved.
 */

import Foundation



public typealias Str2AttrStrXibLocInfo = XibLocResolvingInfo<String, NSMutableAttributedString>

public extension XibLocResolvingInfo where SourceType == String, ReturnType == NSMutableAttributedString {
	
	public enum BoldOrItalicType {
		
		case `default`
		case custom(XibLocFont)
		
	}
	
	public init(strResolvingInfo: Str2StrXibLocInfo, boldType: BoldOrItalicType? = nil, italicType: BoldOrItalicType? = nil, baseFont: XibLocFont?, baseColor: XibLocColor?, returnTypeReplacements: [OneWordTokens: (_ originalValue: NSMutableAttributedString) -> NSMutableAttributedString]? = nil, defaultAttributes: [NSAttributedStringKey: Any]? = di.defaultStr2AttrStrAttributes) {
		var defaultAttributesBuilding = defaultAttributes ?? [:]
		if let f = baseFont  {defaultAttributesBuilding[.font] = f}
		if let c = baseColor {defaultAttributesBuilding[.foregroundColor] = c}
		
		var attributesReplacementsBuilding = [String : StringAttributesChangesDescription]()
		switch boldType {
		case .default?:          attributesReplacementsBuilding["*"] = StringAttributesChangesDescription(changes: [.setBold])
		case .custom(let font)?: attributesReplacementsBuilding["*"] = StringAttributesChangesDescription(changes: [.changeFont(newFont: font, preserveSizes: true, preserveBold: false, preserveItalic: true)])
		default: (/*nop*/)
		}
		switch italicType {
		case .default?:          attributesReplacementsBuilding["_"] = StringAttributesChangesDescription(changes: [.setItalic])
		case .custom(let font)?: attributesReplacementsBuilding["_"] = StringAttributesChangesDescription(changes: [.changeFont(newFont: font, preserveSizes: true, preserveBold: true, preserveItalic: false)])
		default: (/*nop*/)
		}
		
		self.init(strResolvingInfo: strResolvingInfo, attributesReplacements: attributesReplacementsBuilding, returnTypeReplacements: returnTypeReplacements, defaultAttributes: defaultAttributesBuilding)
	}
	
	/** Inits the Str2AttrStrXibLocInfo, copying the string resolving info from
	`strResolvingInfo`. `simpleSourceTypeReplacements` is ignored from the string
	resolving info. */
	public init(strResolvingInfo: Str2StrXibLocInfo, attributesReplacements: [String: StringAttributesChangesDescription], returnTypeReplacements: [OneWordTokens: (_ originalValue: NSMutableAttributedString) -> NSMutableAttributedString]? = nil, defaultAttributes: [NSAttributedStringKey: Any]? = di.defaultStr2AttrStrAttributes) {
		defaultPluralityDefinition = strResolvingInfo.defaultPluralityDefinition
		escapeToken = strResolvingInfo.escapeToken
		pluralGroups = strResolvingInfo.pluralGroups
		orderedReplacements = strResolvingInfo.orderedReplacements
		simpleSourceTypeReplacements = strResolvingInfo.simpleReturnTypeReplacements
		
		var attributesModificationsBuilding = Dictionary<OneWordTokens, (_ modified: inout NSMutableAttributedString, _ strRange: Range<String.Index>, _ refStr: String) -> Void>()
		for (t, c) in attributesReplacements {
			attributesModificationsBuilding[OneWordTokens(token: t)] = { attrStr, strRange, refStr in
				assert(refStr == attrStr.string)
				c.apply(to: attrStr, range: NSRange(strRange, in: refStr))
			}
		}
		attributesModifications = attributesModificationsBuilding
		
		simpleReturnTypeReplacements = returnTypeReplacements ?? [:]
		
		dictionaryReplacements = nil
		identityReplacement = { NSMutableAttributedString(string: $0, attributes: defaultAttributes) }
	}
	
}