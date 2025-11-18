// MessageUtils.qml
pragma Singleton
import QtQml

QtObject {
    function hasThinkingTag(text) {
        return text.indexOf("<think>") !== -1;
    }

    function extractThinkingContent(text) {
        var thinkStart = text.indexOf("<think>");
        if (thinkStart === -1) return "";
        
        var thinkEnd = text.indexOf("</think>");
        
        if (thinkEnd !== -1) {
            return text.substring(thinkStart + 7, thinkEnd).trim();
        } else {
            return text.substring(thinkStart + 7).trim();
        }
    }

    function getMainContent(text) {
        var result = removeSearch(text);
        
        var thinkStart = result.indexOf("<think>");
        if (thinkStart === -1) {
            return result.trim();
        }
        
        var thinkEnd = result.indexOf("</think>");
        if (thinkEnd === -1) {
            return result.substring(0, thinkStart).trim();
        }
        
        var before = result.substring(0, thinkStart);
        var after = result.substring(thinkEnd + 8);
        return (before + " " + after).trim();
    }

    function removeSearch(text) {
        var result = text;
        var searchStart = text.indexOf("search(");
        
        while (searchStart !== -1) {
            var searchEnd = text.indexOf(")", searchStart);
            if (searchEnd !== -1) {
                result = result.substring(0, searchStart) + result.substring(searchEnd + 1);
                searchStart = result.indexOf("search(");
            } else {
                break;
            }
        }
        
        return result.trim();
    }
}