/*
 * ParsedXibLoc.swift
 * XibLoc
 *
 * Created by François Lamboley on 8/26/17.
 * Copyright © 2017 happn. All rights reserved.
 */

import Foundation



struct ParsedXibLoc<SourceTypeHelper : ParserHelper> {
	
	typealias SourceType = SourceTypeHelper.ParsedType
	
	/* Would prefer embedded in Replacement, but makes Swift crash :( (Xcode 9.1/9B55) */
	enum ReplacementValue {
		
		class MutableCount {
			var value: Int
			init(v: Int) {value = v}
		}
		
		class MutableKeysList {
			var keys: Set<String>
			var hasDefaultValue: Bool
			init() {keys = []; hasDefaultValue = false}
		}
		
		case simpleSourceTypeReplacement(OneWordTokens)
		case orderedReplacement(MultipleWordsTokens, valueIndex: Int, numberOfValues: MutableCount)
		case pluralGroup(MultipleWordsTokens, zoneIndex: Int, numberOfZones: MutableCount)
		
		case attributesModification(OneWordTokens)
		case simpleReturnTypeReplacement(OneWordTokens)
		
		case dictionaryReplacement(id: String, key: String?, allKeys: MutableKeysList)
		
		var isAttributesModifiation: Bool {
			switch self {
			case .attributesModification: return true
			default:                      return false
			}
		}
		
	}
	
	/* Note: I'm not so sure having a struct here is such a good idea... We have
	 *       to workaround a lot the fact that we pass replacements by value
	 *       instead of pointers to replacements... */
	struct Replacement {
		
		let groupId: Int
		
		var range: Range<String.Index>
		let value: ReplacementValue
		
		var removedLeftTokenDistance: String.IndexDistance
		var removedRightTokenDistance: String.IndexDistance
		var containerRange: Range<String.Index> /* Always contains “range”. Equals “range” for OneWordTokens. */
		
		var children: [Replacement]
		
		func print(from string: String, prefix: String = "") {
			Swift.print("\(prefix)REPLACEMENT START")
			Swift.print("\(prefix)container: \(string[containerRange])")
			Swift.print("\(prefix)range: \(string[range])")
			Swift.print("\(prefix)removed left  token distance: \(removedLeftTokenDistance)")
			Swift.print("\(prefix)removed right token distance: \(removedRightTokenDistance)")
			Swift.print("\(prefix)children (\(children.count))")
			for c in children {c.print(from: string, prefix: prefix + "   ")}
			Swift.print("\(prefix)REPLACEMENT END")
		}
		
	}
	
	/* We _may_ want to migrate these three variables to a private let... Some
	 * client _might_ need those however, so let's keep them accessible (TBD). */
	let replacements: [Replacement]
	let untokenizedSource: SourceType
	let untokenizedStringSource: String
	let pluralityDefinitions: [MultipleWordsTokens: PluralityDefinition]
	
	let sourceTypeHelperType: SourceTypeHelper.Type
	
	init<DestinationType>(source: SourceType, parserHelper: SourceTypeHelper.Type, forXibLocResolvingInfo xibLocResolvingInfo: XibLocResolvingInfo<SourceType, DestinationType>) {
		self.init(source: source, parserHelper: parserHelper, escapeToken: xibLocResolvingInfo.escapeToken, simpleSourceTypeReplacements: Array(xibLocResolvingInfo.simpleSourceTypeReplacements.keys), orderedReplacements: Array(xibLocResolvingInfo.orderedReplacements.keys), pluralGroups: Array(xibLocResolvingInfo.pluralGroups.map{ $0.0 }), attributesModifications: Array(xibLocResolvingInfo.attributesModifications.keys), simpleReturnTypeReplacements: Array(xibLocResolvingInfo.simpleReturnTypeReplacements.keys), hasDictionaryReplacements: xibLocResolvingInfo.dictionaryReplacements != nil)
	}
	
	init(source: SourceType, parserHelper: SourceTypeHelper.Type, escapeToken: String?, simpleSourceTypeReplacements: [OneWordTokens], orderedReplacements: [MultipleWordsTokens], pluralGroups: [MultipleWordsTokens], attributesModifications: [OneWordTokens], simpleReturnTypeReplacements: [OneWordTokens], hasDictionaryReplacements: Bool) {
		var source = SourceTypeHelper.copy(source: source)
		var stringSource = parserHelper.stringRepresentation(of: source)
		var pluralityDefinitionsList = ParsedXibLoc.preprocessForPluralityDefinitionOverrides(source: &source, stringSource: &stringSource, parserHelper: parserHelper)
		while pluralityDefinitionsList.count < pluralGroups.count {pluralityDefinitionsList.append(nil)}
		
		self.init(source: source, stringSource: stringSource, parserHelper: parserHelper, escapeToken: escapeToken, simpleSourceTypeReplacements: simpleSourceTypeReplacements, orderedReplacements: orderedReplacements, pluralGroups: pluralGroups, attributesModifications: attributesModifications, simpleReturnTypeReplacements: simpleReturnTypeReplacements, hasDictionaryReplacements: hasDictionaryReplacements, pluralityDefinitionsList: pluralityDefinitionsList)
	}
	
	private init(source: SourceType, stringSource: String, parserHelper: SourceTypeHelper.Type, escapeToken: String?, simpleSourceTypeReplacements: [OneWordTokens], orderedReplacements: [MultipleWordsTokens], pluralGroups: [MultipleWordsTokens], attributesModifications: [OneWordTokens], simpleReturnTypeReplacements: [OneWordTokens], hasDictionaryReplacements: Bool, pluralityDefinitionsList: [PluralityDefinition?]) {
		let warning = "todo: cache"
		assert(pluralityDefinitionsList.count >= pluralGroups.count)
		assert(!hasDictionaryReplacements, "Not implemented: Creating a ParsedXibLoc with dictionary replacements")
		/* First, let's make sure we are not overlapping tokens for our parsing:
		 *    - If lsep == rsep, reduce to only sep;
		 *    - No char used in any separator (left, right, internal, escape token) must be use in another separator;
		 *    - But the same char can be used multiple time in one separator;
		 *    - If dictionary replacements are active, the following tokens are reserved (and count in the above rules): "@[", "|", ":", "¦", "]"
		 * We'll also make sure none of the tokens are empty. */
		#if !NS_BLOCK_ASSERTIONS // TODO: Find correct pre-processing instruction
			var chars = !hasDictionaryReplacements ? Set<Character>() : Set<Character>(arrayLiteral: "@", "[", "|", ":", "¦", "]")
			
			let processToken = { (token: String) in
				assert(!token.isEmpty)
				let tokenChars = Set(token)
				assert(chars.intersection(tokenChars).isEmpty)
				chars.formUnion(tokenChars)
			}
			
			if let e = escapeToken {processToken(e)}
			
			for w in (simpleSourceTypeReplacements + attributesModifications + simpleReturnTypeReplacements) {
				processToken(w.leftToken)
				if w.leftToken != w.rightToken {processToken(w.rightToken)}
			}
			
			for w in (orderedReplacements + pluralGroups) {
				processToken(w.leftToken)
				processToken(w.interiorToken)
				if w.leftToken != w.rightToken {processToken(w.rightToken)}
			}
		#endif
		
		/* Let's build the replacements. Overlaps are allowed with the following rules:
		 *    - The attributes modifications can overlap between themselves at will;
		 *    - Replacements can be embedded in other replacements (internal ranges for multiple words tokens, default or other values ranges for dictionaries);
		 *    - Replacements cannot overlap attributes modifications or replacements if one is not fully embedded in the other.
		 * Note: Anything can be embedded in a simple replacement, but everything embedded in it will be dropped... (the content is replaced, by definition!) */
		
		func getOneWordRanges(tokens: [OneWordTokens], replacementTypeBuilder: (_ token: OneWordTokens) -> ReplacementValue, currentGroupId: inout Int, in output: inout [Replacement]) {
			for sep in tokens {
				var pos = stringSource.startIndex
				while let r = ParsedXibLoc.rangeFrom(leftSeparator: sep.leftToken, rightSeparator: sep.rightToken, escapeToken: escapeToken, baseString: stringSource, currentPositionInString: &pos) {
					let replacementType = replacementTypeBuilder(sep)
					let doUntokenization = replacementType.isAttributesModifiation /* See discussion below about token removal */
					let contentRange = ParsedXibLoc.contentRange(from: r, in: stringSource, leftSep: sep.leftToken, rightSep: sep.rightToken)
					let replacement = Replacement(groupId: currentGroupId, range: contentRange, value: replacementType, removedLeftTokenDistance: doUntokenization ? sep.leftToken.count : 0, removedRightTokenDistance: doUntokenization ? sep.rightToken.count : 0, containerRange: r, children: [])
					ParsedXibLoc.insert(replacement: replacement, in: &output)
					currentGroupId += 1
				}
			}
		}
		
		func getMultipleWordsRanges(tokens: [MultipleWordsTokens], replacementTypeBuilder: (_ token: MultipleWordsTokens, _ idx: Int, _ count: ReplacementValue.MutableCount) -> ReplacementValue, currentGroupId: inout Int, in output: inout [Replacement]) {
			for sep in tokens {
				var pos = stringSource.startIndex
				while let r = ParsedXibLoc.rangeFrom(leftSeparator: sep.leftToken, rightSeparator: sep.rightToken, escapeToken: escapeToken, baseString: stringSource, currentPositionInString: &pos) {
					/* Let's get the internal ranges. */
					let contentRange = ParsedXibLoc.contentRange(from: r, in: stringSource, leftSep: sep.leftToken, rightSep: sep.rightToken)
					var startIndex = contentRange.lowerBound
					let endIndex = contentRange.upperBound
					let count = ReplacementValue.MutableCount(v: 1)
					
					var idx = 0
					while let sepRange = ParsedXibLoc.range(of: sep.interiorToken, escapeToken: escapeToken, baseString: stringSource, in: startIndex..<endIndex) {
						let internalRange = startIndex..<sepRange.lowerBound
						/* We set both removed left and right token distances to 0 (see discussion below about token removal) */
						let replacement = Replacement(groupId: currentGroupId, range: internalRange, value: replacementTypeBuilder(sep, idx, count), removedLeftTokenDistance: 0/*idx == 0 ? sep.leftToken.count : 0*/, removedRightTokenDistance: 0/*sep.interiorToken.count*/, containerRange: r, children: [])
						ParsedXibLoc.insert(replacement: replacement, in: &output)
						
						idx += 1
						count.value += 1
						startIndex = sepRange.upperBound
					}
					let internalRange = startIndex..<endIndex
					/* We set both removed left and right token distances to 0 (see discussion below about token removal) */
					let replacement = Replacement(groupId: currentGroupId, range: internalRange, value: replacementTypeBuilder(sep, idx, count), removedLeftTokenDistance: 0/*idx == 0 ? sep.leftToken.count : 0*/, removedRightTokenDistance: 0/*sep.rightToken.count*/, containerRange: r, children: [])
					ParsedXibLoc.insert(replacement: replacement, in: &output)
					currentGroupId += 1
				}
			}
		}
		
		var currentGroupId = 0
		var replacementsBuilding = [Replacement]()
		
		getOneWordRanges(tokens: simpleSourceTypeReplacements, replacementTypeBuilder: { .simpleSourceTypeReplacement($0) }, currentGroupId: &currentGroupId, in: &replacementsBuilding)
		getOneWordRanges(tokens: simpleReturnTypeReplacements, replacementTypeBuilder: { .simpleReturnTypeReplacement($0) }, currentGroupId: &currentGroupId, in: &replacementsBuilding)
		getOneWordRanges(tokens: attributesModifications, replacementTypeBuilder: { .attributesModification($0) }, currentGroupId: &currentGroupId, in: &replacementsBuilding)
		getMultipleWordsRanges(tokens: pluralGroups, replacementTypeBuilder: { .pluralGroup($0, zoneIndex: $1, numberOfZones: $2) }, currentGroupId: &currentGroupId, in: &replacementsBuilding)
		getMultipleWordsRanges(tokens: orderedReplacements, replacementTypeBuilder: { .orderedReplacement($0, valueIndex: $1, numberOfValues: $2) }, currentGroupId: &currentGroupId, in: &replacementsBuilding)
		/* TODO: Parse the dictionary replacements. */
		
		/* Let's remove the tokens we want gone from the source string. The escape
		 * token is always removed. We only remove the left and right separator
		 * tokens from the attributes modification; all other tokens are left. The
		 * idea behind the removal of the tokens is to avoid adjusting all the
		 * ranges in the replacements when applying the changes in the source. The
		 * attributes modification change is guaranteed not to modify the range of
		 * anything by contract, so we can pre-compute the ranges before applying
		 * the modification. All other changes will modify the ranges 99% of the
		 * cases, so there are no pre-computations to be done this way. */
		
		var untokenizedSourceBuilding = source
		var untokenizedStringSourceBuilding = stringSource
		ParsedXibLoc.remove(escapeToken: escapeToken, in: &replacementsBuilding, source: &untokenizedSourceBuilding, stringSource: &untokenizedStringSourceBuilding, parserHelper: parserHelper)
		ParsedXibLoc.removeTokens(from: &replacementsBuilding, source: &untokenizedSourceBuilding, stringSource: &untokenizedStringSourceBuilding, parserHelper: parserHelper)
//		print("***** RESULTS TIME *****")
//		print("untokenized: \(untokenizedStringSourceBuilding)")
//		for r in replacementsBuilding {r.print(from: untokenizedStringSourceBuilding)}
		
		/* Let's finish the init */
		
		sourceTypeHelperType = parserHelper
		
		replacements = replacementsBuilding
		untokenizedSource = untokenizedSourceBuilding
		untokenizedStringSource = untokenizedStringSourceBuilding
		
		/* Plurality definitions overrides */
		var pluralityDefinitionsBuilding = [MultipleWordsTokens: PluralityDefinition]()
		for (pluralityDefinition, pluralGroup) in zip(pluralityDefinitionsList, pluralGroups) {
			guard let pluralityDefinition = pluralityDefinition else {continue}
			pluralityDefinitionsBuilding[pluralGroup] = pluralityDefinition
		}
		pluralityDefinitions = pluralityDefinitionsBuilding
	}
	
	func resolve<ReturnTypeHelper : ParserHelper>(xibLocResolvingInfo: XibLocResolvingInfo<SourceType, ReturnTypeHelper.ParsedType>, returnTypeHelperType: ReturnTypeHelper.Type) -> ReturnTypeHelper.ParsedType {
		let replacementsIterator = ReplacementsIterator(refString: untokenizedStringSource, adjustedReplacements: replacements)
		
		var pluralGroupsDictionary = [MultipleWordsTokens: PluralValue]()
		xibLocResolvingInfo.pluralGroups.forEach{ pluralGroupsDictionary[$0.0] = $0.1 }
		
		/* Applying simple source type replacements */
		var sourceWithSimpleReplacements = SourceTypeHelper.copy(source: untokenizedSource)
		while let replacement = replacementsIterator.next() {
			guard case .simpleSourceTypeReplacement(let token) = replacement.value else {continue}
			guard let newValue = xibLocResolvingInfo.simpleSourceTypeReplacements[token] else {
				NSLog("%@", "Got token \(token) in replacement tree for simple source type replacement, but no value given in xibLocResolvingInfo") /* HCLogES */
				continue
			}
			
			let stringReplacement = sourceTypeHelperType.replace(strRange: (replacement.containerRange, replacementsIterator.refString), with: newValue, in: &sourceWithSimpleReplacements)
			
			replacementsIterator.delete(replacementGroup: replacement.groupId)
			replacementsIterator.replace(rangeInText: replacement.containerRange, with: stringReplacement)
		}
		
		/* Converting the source type string to the destination type */
		var result = xibLocResolvingInfo.identityReplacement(sourceWithSimpleReplacements)
		replacementsIterator.reset()
		
		/* Applying other replacements */
		while let replacement = replacementsIterator.next() {
			switch replacement.value {
			case .simpleSourceTypeReplacement: (/* Treated before conversion to ReturnType */)
			case .attributesModification(let token):
				guard let modifier = xibLocResolvingInfo.attributesModifications[token] else {
					NSLog("%@", "Got token \(token) in replacement tree for attributes modification, but no value given in xibLocResolvingInfo") /* HCLogES */
					continue
				}
				modifier(&result, replacement.range, replacementsIterator.refString)
				assert(returnTypeHelperType.stringRepresentation(of: result) == replacementsIterator.refString)
				replacementsIterator.delete(replacementGroup: replacement.groupId)
				
			case .simpleReturnTypeReplacement(let token):
				guard let newValue = xibLocResolvingInfo.simpleReturnTypeReplacements[token] else {
					NSLog("%@", "Got token \(token) in replacement tree for simple return type replacement, but no value given in xibLocResolvingInfo") /* HCLogES */
					continue
				}
				
				let stringReplacement = returnTypeHelperType.replace(strRange: (replacement.containerRange, replacementsIterator.refString), with: newValue, in: &result)
				replacementsIterator.delete(replacementGroup: replacement.groupId)
				replacementsIterator.replace(rangeInText: replacement.containerRange, with: stringReplacement)
				
			case .orderedReplacement(let token, valueIndex: let valueIndex, numberOfValues: let numberOfValues):
				guard let wantedValue = xibLocResolvingInfo.orderedReplacements[token] else {
					NSLog("%@", "Got token \(token) in replacement tree for ordered replacement, but no value given in xibLocResolvingInfo") /* HCLogES */
					continue
				}
				guard valueIndex == wantedValue || (wantedValue >= numberOfValues.value && valueIndex == numberOfValues.value-1) else {continue}
				
				let content = returnTypeHelperType.slice(strRange: (replacement.range, replacementsIterator.refString), from: result)
				let stringContent = returnTypeHelperType.replace(strRange: (replacement.containerRange, replacementsIterator.refString), with: content, in: &result)
				replacementsIterator.delete(replacementGroup: replacement.groupId)
				replacementsIterator.replace(rangeInText: replacement.containerRange, with: stringContent)
				
			case .pluralGroup(let token, zoneIndex: let zoneIndex, numberOfZones: let numberOfZones):
				guard let wantedValue = pluralGroupsDictionary[token] else {
					NSLog("%@", "Got token \(token) in replacement tree for plural replacement, but no value given in xibLocResolvingInfo") /* HCLogES */
					continue
				}
				let pluralityDefinition = pluralityDefinitions[token] ?? xibLocResolvingInfo.defaultPluralityDefinition
				let indexToUse = pluralityDefinition.indexOfVersionToUse(forValue: wantedValue, numberOfVersions: numberOfZones.value) /* Let's use the default defaultFloatPrecision! */
				assert(indexToUse <= numberOfZones.value)
				
				guard zoneIndex == indexToUse else {continue}
				
				let content = returnTypeHelperType.slice(strRange: (replacement.range, replacementsIterator.refString), from: result)
				let stringContent = returnTypeHelperType.replace(strRange: (replacement.containerRange, replacementsIterator.refString), with: content, in: &result)
				replacementsIterator.delete(replacementGroup: replacement.groupId)
				replacementsIterator.replace(rangeInText: replacement.containerRange, with: stringContent)
				
			case .dictionaryReplacement(id: let id, key: let key, allKeys: let allKeys):
				/* Note: The dictionary replacement has never been tested (parsing not implemented yet). */
				guard let dictionaryReplacements = xibLocResolvingInfo.dictionaryReplacements else {
					NSLog("%@", "Got dictionary with id \(id) in replacement tree, but no dictionary replacements in xibLocResolvingInfo") /* HCLogES */
					continue
				}
				guard let wantedKey = dictionaryReplacements[id] else {
					/* Not an error to have a dictionary whose id is not in the dictionary replacements says the spec. Simply ignore this replacement group. */
					replacementsIterator.delete(replacementGroup: replacement.groupId)
					continue
				}
				let parsedDictionaryHasWantedKey = wantedKey.map{ allKeys.keys.contains($0) } ?? allKeys.hasDefaultValue
				guard parsedDictionaryHasWantedKey || allKeys.hasDefaultValue else {
					/* The key we want is not contained in the parsed dictionary, and
					 * the dictionary does not have a default value. We can simply
					 * remove the whole dictionary. */
					returnTypeHelperType.remove(strRange: (replacement.containerRange, replacementsIterator.refString), from: &result)
					replacementsIterator.delete(replacementGroup: replacement.groupId)
					replacementsIterator.delete(rangeInText: replacement.containerRange)
					continue
				}
				
				guard wantedKey == key || (!parsedDictionaryHasWantedKey && key == nil) else {continue}
				
				let content = returnTypeHelperType.slice(strRange: (replacement.range, replacementsIterator.refString), from: result)
				let stringContent = returnTypeHelperType.replace(strRange: (replacement.containerRange, replacementsIterator.refString), with: content, in: &result)
				replacementsIterator.delete(replacementGroup: replacement.groupId)
				replacementsIterator.replace(rangeInText: replacement.containerRange, with: stringContent)
			}
		}
		
		return result
	}
	
	/* ***************
      MARK: - Private
	   *************** */
	
	/* *************************
      MARK: → General Utilities
	   ************************* */
	
	private class ReplacementsIterator : IteratorProtocol {
		
		typealias Element = Replacement
		
		var refString: String
		var adjustedReplacements: [Replacement]
		
		init(refString rs: String, adjustedReplacements r: [Replacement]) {
//			print("RESET I")
			refString = rs
			adjustedReplacements = r
		}
		
		func next() -> Replacement? {
//			print("ASKED NEXT REPLACEMENT. CURRENT INDEX PATH IS \(currentIndexPath); refString is \(refString)")
//			defer {print(" --> NEW CURRENT INDEX PATH: \(currentIndexPath)")}
			/* Moving currentIndexPath to next index path. Depth-first graph traversal style. */
			if wentIn {
				func isLastIndexInParent(_ indexPath: IndexPath) -> Bool {
					guard let lastIndex = indexPath.last else {return false}
					let parentIndexPath = indexPath.dropLast()
					if parentIndexPath.isEmpty {return lastIndex == adjustedReplacements.endIndex-1}
					else                       {return lastIndex == replacement(at: parentIndexPath).children.endIndex-1}
				}
				
				if isLastIndexInParent(currentIndexPath) {currentIndexPath.removeLast(); wentIn = true}
				else {
					guard let lastIndex = currentIndexPath.last else {/*print(" --> RETURNING NIL"); */return nil}
					currentIndexPath.removeLast(); currentIndexPath.append(lastIndex + 1)
					wentIn = false
				}
			}
			if !wentIn {
				while (currentIndexPath.count == 0 && adjustedReplacements.count > 0) || (currentIndexPath.count > 0 && replacement(at: currentIndexPath).children.count > 0) {currentIndexPath.append(0)}
				wentIn = true
			}
			
			/* Returning Replacement at currentIndexPath */
			guard currentIndexPath.count > 0 else {/*print(" --> RETURNING NIL"); */return nil}
//			print(" --> RETURNING AT INDEX PATH \(currentIndexPath)")
			return replacement(at: currentIndexPath)
		}
		
		func reset() {
//			print("RESET")
			currentIndexPath = IndexPath()
			wentIn = false
		}
		
		func delete(replacementGroup: Int) {
			delete(replacementGroup: replacementGroup, in: &adjustedReplacements)
		}
		
		func replace(rangeInText replacedRange: Range<String.Index>, with string: String?) {
			let originalString = refString
			refString.replaceSubrange(replacedRange, with: string ?? "")
			ReplacementsIterator.adjustReplacementRanges(replacedRange: replacedRange, with: string?.count, in: &adjustedReplacements, originalString: originalString, newString: refString)
		}
		
		func delete(rangeInText replacedRange: Range<String.Index>) {
			replace(rangeInText: replacedRange, with: nil)
		}
		
		private var currentIndexPath = IndexPath()
		private var wentIn = false
		
		/* range and removedRange are relative to originalString
		 * addedDistance is relative to newString */
		private static func adjustedRange(from range: Range<String.Index>, byReplacing removedRange: Range<String.Index>, in originalString: String, with addedDistance: (String.IndexDistance, String)?) -> Range<String.Index> {
			let adjustLowerBound = (originalString.distance(from: range.lowerBound, to: removedRange.upperBound) <= 0)
			let adjustUpperBound = (originalString.distance(from: range.upperBound, to: removedRange.upperBound) <= 0)
			let removedDistance = originalString.distance(from: removedRange.lowerBound, to: removedRange.upperBound)
			
			let adjustedLowerBoundWithRemoval = !adjustLowerBound ? range.lowerBound : originalString.index(range.lowerBound, offsetBy: -removedDistance)
			let adjustedUpperBoundWithRemoval = !adjustUpperBound ? range.upperBound : originalString.index(range.upperBound, offsetBy: -removedDistance)
			
			if let (addedDistance, newString) = addedDistance {
				return Range<String.Index>(uncheckedBounds:
					(lower: !adjustLowerBound ? adjustedLowerBoundWithRemoval : newString.index(adjustedLowerBoundWithRemoval, offsetBy: addedDistance),
					 upper: !adjustUpperBound ? adjustedUpperBoundWithRemoval : newString.index(adjustedUpperBoundWithRemoval, offsetBy: addedDistance))
				)
			}
			
			return Range<String.Index>(uncheckedBounds: (lower: adjustedLowerBoundWithRemoval, upper: adjustedUpperBoundWithRemoval))
		}
		
		private static func adjustReplacementRanges(replacedRange: Range<String.Index>, with distance: String.IndexDistance?, in replacements: inout [Replacement], originalString: String, newString: String) {
			for (idx, var replacement) in replacements.enumerated() {
				/* We make sure range is contained by the container range of the
				 * replacement, or that both do not overlap. */
				assert(!replacement.containerRange.overlaps(replacedRange) || replacement.containerRange.clamped(to: replacedRange) == replacedRange)
				
				replacement.range          = ReplacementsIterator.adjustedRange(from: replacement.range,          byReplacing: replacedRange, in: originalString, with: distance.map{ ($0, newString) })
				replacement.containerRange = ReplacementsIterator.adjustedRange(from: replacement.containerRange, byReplacing: replacedRange, in: originalString, with: distance.map{ ($0, newString) })
				
				adjustReplacementRanges(replacedRange: replacedRange, with: distance, in: &replacement.children, originalString: originalString, newString: newString)
				replacements[idx] = replacement
			}
		}
		
		private func delete(replacementGroup deletedGroupId: Int, in replacements: inout [Replacement], currentLevel: Int = 0) {
			var idx = 0
			while idx < replacements.count {
				var replacement = replacements[idx]
				
				guard replacement.groupId != deletedGroupId else {
					if currentLevel < currentIndexPath.endIndex {
						switch currentIndexPath[currentLevel] {
						case idx:
							/* The replacement we are removing is currently being
							 * visited. Let's relocate the current index to the
							 * previous replacement. */
							currentIndexPath.removeLast(currentIndexPath.count-currentLevel-1)
							while let last = currentIndexPath.last, last == 0 {currentIndexPath.removeLast()}
							if let last = currentIndexPath.last {currentIndexPath.removeLast(); currentIndexPath.append(last - 1)}
							else                                {wentIn = false}
							
						case idx...:
							currentIndexPath[currentLevel] -= 1
							
						default: (/*nop*/)
						}
					}
					replacements.remove(at: idx)
					continue
				}
				
				delete(replacementGroup: deletedGroupId, in: &replacement.children, currentLevel: currentLevel+1)
				replacements[idx] = replacement
				
				idx += 1
			}
		}
		
		private func replacement(at indexPath: IndexPath) -> Replacement {
			var result: Replacement!
			var replacements = adjustedReplacements
			for idx in indexPath {
				result = replacements[idx]
				replacements = result.children
			}
			return result
		}
		
	}
	
	/* **************************
      MARK: → Parsing the XibLoc
	   ************************** */
	
	private static func remove(escapeToken: String?, in replacements: inout [Replacement], source: inout SourceType, stringSource: inout String, parserHelper: SourceTypeHelper.Type) {
		guard let escapeToken = escapeToken else {return}
		
		let iterator = ReplacementsIterator(refString: stringSource, adjustedReplacements: replacements)
		
		var pos = iterator.refString.startIndex
		while let r = iterator.refString.range(of: escapeToken, options: [.literal], range: pos..<iterator.refString.endIndex) {
			parserHelper.remove(strRange: (r, iterator.refString), from: &source)
			iterator.delete(rangeInText: r)
			pos = r.lowerBound
			
			if pos >= iterator.refString.endIndex {break}
			if iterator.refString[r] == escapeToken {pos = iterator.refString.index(pos, offsetBy: escapeToken.count)}
		}
		
		replacements = iterator.adjustedReplacements
		stringSource = iterator.refString
	}
	
	private static func removeTokens(from replacements: inout [Replacement], source: inout SourceType, stringSource: inout String, parserHelper: SourceTypeHelper.Type) {
		let iterator = ReplacementsIterator(refString: stringSource, adjustedReplacements: replacements)
		
		while let replacement = iterator.next() {
			let leftTokenRange = iterator.refString.index(replacement.range.lowerBound, offsetBy: -replacement.removedLeftTokenDistance)..<replacement.range.lowerBound
			parserHelper.remove(strRange: (leftTokenRange, iterator.refString), from: &source)
			iterator.delete(rangeInText: leftTokenRange)
		}
		iterator.reset()
		while let replacement = iterator.next() {
			let rightTokenRange = replacement.range.upperBound..<iterator.refString.index(replacement.range.upperBound, offsetBy: replacement.removedRightTokenDistance)
			parserHelper.remove(strRange: (rightTokenRange, iterator.refString), from: &source)
			iterator.delete(rangeInText: rightTokenRange)
		}
		
		replacements = iterator.adjustedReplacements
		stringSource = iterator.refString
	}
	
	/** Inserts the given replacement in the given array of replacements, if
	possible. If a valid insertion cannot be done, returns `false` (otherwise,
	returns `true`).
	Assumes the given replacement and current replacements are valid. */
	@discardableResult
	private static func insert(replacement: Replacement, in currentReplacements: inout [Replacement]) -> Bool {
		for (idx, checkedReplacement) in currentReplacements.enumerated() {
			/* If both checked and inserted replacements have the same container
			 * range, we are inserting a new replacement value for the checked
			 * replacement (eg. inserting the “b” when “a” has been inserted in the
			 * following replacement: “<a:b>”). Let's just check the two ranges do
			 * not overlap (asserted, this is an internal logic error if ranges
			 * overlap). */
			guard replacement.containerRange != checkedReplacement.containerRange else {
				assert(!replacement.range.overlaps(checkedReplacement.range))
				continue
			}
			
			/* If there are no overlaps of the container ranges, or if we have two
			 * attributes modifications, we have an easy case: nothing to do (all
			 * ranges are valid). */
			guard !replacement.value.isAttributesModifiation || !checkedReplacement.value.isAttributesModifiation else {continue}
			guard replacement.containerRange.overlaps(checkedReplacement.containerRange) else {continue}
			
			if checkedReplacement.range.clamped(to: replacement.containerRange) == replacement.containerRange {
				/* replacement’s container range is included in checkedReplacement’s range: we must add replacement as a child of checkedReplacement */
				var checkedReplacement = checkedReplacement
				guard insert(replacement: replacement, in: &checkedReplacement.children) else {return false}
				currentReplacements[idx] = checkedReplacement
				return true
			} else if replacement.range.clamped(to: checkedReplacement.containerRange) == checkedReplacement.containerRange {
				/* checkedReplacement’s container range is included in replacement’s range: we must add checkedReplacement as a child of replacement */
				var replacement = replacement
				guard insert(replacement: checkedReplacement, in: &replacement.children) else {return false}
				currentReplacements[idx] = replacement
				return true
			} else {
				return false
			}
		}
		
		currentReplacements.append(replacement)
		return true
	}
	
	private static func preprocessForPluralityDefinitionOverrides(source: inout SourceType, stringSource: inout String, parserHelper: SourceTypeHelper.Type) -> [PluralityDefinition?] {
		guard stringSource.hasPrefix("||") else {return []}
		
		let startIdx = stringSource.startIndex
		
		/* We might have plurality overrides. Let's check. */
		guard !stringSource.hasPrefix("|||") else {
			/* We don't. But we must remove one leading "|". */
			parserHelper.remove(strRange: (..<stringSource.index(after: startIdx), stringSource), from: &source)
			stringSource.removeFirst()
			return []
		}
		
		let pluralityStringStartIdx = stringSource.index(startIdx, offsetBy: 2)
		
		/* We do have plurality override(s)! Is it valid? */
		guard let pluralityEndIdx = stringSource.range(of: "||", options: [.literal], range: pluralityStringStartIdx..<stringSource.endIndex)?.lowerBound else {
			/* Nope. It is not. */
			NSLog("%@", "Got invalid plurality override in string \(source)") /* We used to use HCLogES */
			return []
		}
		
		/* A valid plurality overrides part was found. Let's parse them! */
		let pluralityOverrideStr = stringSource[pluralityStringStartIdx..<pluralityEndIdx]
		let pluralityDefinitions = pluralityOverrideStr.components(separatedBy: "|").map{ $0 == "_" ? nil : PluralityDefinition(string: $0) }
		
		/* Let's remove the plurality definition from the string. */
		let nonPluralityStringStartIdx = stringSource.index(pluralityEndIdx, offsetBy: 2)
		parserHelper.remove(strRange: (..<nonPluralityStringStartIdx, stringSource), from: &source)
		stringSource.removeSubrange(startIdx..<nonPluralityStringStartIdx)

		return pluralityDefinitions
	}
	
	private static func contentRange(from range: Range<String.Index>, in source: String, leftSep: String, rightSep: String) -> Range<String.Index> {
		assert(source.distance(from: range.lowerBound, to: range.upperBound) >= leftSep.count + rightSep.count)
		return Range<String.Index>(uncheckedBounds: (lower: source.index(range.lowerBound, offsetBy: leftSep.count), upper: source.index(range.upperBound, offsetBy: -rightSep.count)))
	}
	
	private static func rangeFrom(leftSeparator: String, rightSeparator: String, escapeToken: String?, baseString: String, currentPositionInString: inout String.Index) -> Range<String.Index>? {
		guard let leftSeparatorRange = range(of: leftSeparator, escapeToken: escapeToken, baseString: baseString, in: currentPositionInString..<baseString.endIndex) else {
			currentPositionInString = baseString.endIndex
			return nil
		}
		currentPositionInString = leftSeparatorRange.upperBound
		
		guard let rightSeparatorRange = range(of: rightSeparator, escapeToken: escapeToken, baseString: baseString, in: currentPositionInString..<baseString.endIndex) else {
			/* Invalid string: The left token was found, but the right is not. */
			NSLog("%@", "Invalid baseString \"\(baseString)\": left token “\(leftSeparator)” was found, but right one “\(rightSeparator)” was not. Ignoring.") /* HCLogES */
			currentPositionInString = baseString.endIndex
			return nil
		}
		currentPositionInString = rightSeparatorRange.upperBound
		
		return leftSeparatorRange.lowerBound..<rightSeparatorRange.upperBound
	}
	
	private static func range(of separator: String, escapeToken: String?, baseString: String, in range: Range<String.Index>) -> Range<String.Index>? {
		var escaped: Bool
		var ret: Range<String.Index>
		
		var startIndex = range.lowerBound
		let endIndex = range.upperBound
		
		repeat {
			guard let rl = baseString.range(of: separator, options: [.literal], range: startIndex..<endIndex) else {
				return nil
			}
			startIndex = rl.upperBound
			escaped = isTokenInRange(rl, fromString: baseString, escapedWithToken: escapeToken)
			
			ret = rl
		} while escaped
		
		return ret
	}
	
	private static func isTokenInRange(_ range: Range<String.Index>, fromString baseString: String, escapedWithToken token: String?) -> Bool {
		guard let escapeToken = token, !escapeToken.isEmpty else {return false}
		
		var wasMatch = true
		var nMatches = 0
		var curPos = range.lowerBound
		while curPos >= escapeToken.endIndex && wasMatch {
			curPos = baseString.index(curPos, offsetBy: -escapeToken.count)
			wasMatch = (baseString[curPos..<baseString.index(curPos, offsetBy: escapeToken.count)] == escapeToken)
			if wasMatch {nMatches += 1}
		}
		return (nMatches % 2) == 1
	}
	
}
