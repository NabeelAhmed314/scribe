let Hooks = {}

Hooks.Clipboard = {
    mounted() {
        this.handleEvent("copy-to-clipboard", ({ text: text }) => {
            navigator.clipboard.writeText(text).then(() => {
                this.pushEventTo(this.el, "copied-to-clipboard", { text: text })
                setTimeout(() => {
                    this.pushEventTo(this.el, "reset-copied", {})
                }, 2000)
            })
        })
    }
}

Hooks.RichTextInput = {
    mounted() {
        this.mentionQuery = ""
        this.mentionStartPos = -1
        this.skipNextSync = false
        
        // Initialize with data from attributes
        const initialMessage = this.el.dataset.message || ""
        if (initialMessage) {
            this.renderContent(initialMessage)
        }
        
        // Track if user is actively typing
        this.isTyping = false
        
        // Handle input
        this.el.addEventListener("input", (e) => {
            this.isTyping = true
            this.checkForMention()
            this.syncToLiveView()
        })
        
        // Track typing state
        this.el.addEventListener("focus", () => {
            this.isTyping = true
            // Save cursor position before converting
            const selection = window.getSelection()
            const savedOffset = this.saveCursorPosition()
            
            // Show plain text while typing
            const message = this.getPlainText()
            if (this.el.innerHTML !== message) {
                this.el.textContent = message
                // Restore cursor position
                this.restoreCursorPosition(savedOffset)
            }
        })
        
        // Handle special keys
        this.el.addEventListener("keydown", (e) => {
            if (e.key === "Enter" && (e.metaKey || e.ctrlKey)) {
                e.preventDefault()
                this.pushEvent("send_message", {})
            }
        })
        
        // Handle server-pushed updates (from Add Context or Select Mention)
        this.handleEvent("update_textarea", ({ message, contacts }) => {
            this.renderContent(message, contacts)
            // Move cursor to end
            setTimeout(() => {
                const range = document.createRange()
                range.selectNodeContents(this.el)
                range.collapse(false)
                const selection = window.getSelection()
                selection.removeAllRanges()
                selection.addRange(range)
            }, 0)
        })
        
        // Re-render with styled mentions when user leaves
        this.el.addEventListener("blur", () => {
            this.isTyping = false
            setTimeout(() => {
                const message = this.getPlainText()
                this.renderContent(message)
            }, 200)
        })
    },
    
    renderContent(message, explicitContacts = null) {
        // Don't render badges if user is actively typing
        if (this.isTyping && document.activeElement === this.el) {
            // Show plain text while typing
            this.el.textContent = message
            return
        }
        
        if (!message || message === "") {
            this.el.innerHTML = ""
            return
        }
        
        // Get contacts data for styling
        let contacts = explicitContacts || []
        if (!explicitContacts) {
            try {
                contacts = JSON.parse(this.el.dataset.contacts || "[]")
            } catch (e) {
                contacts = []
            }
        }
        
        // Create a map of firstname -> source
        const contactSources = {}
        contacts.forEach(contact => {
            const firstname = contact.firstname || contact["firstname"]
            const source = contact.source || contact["source"]
            if (firstname) {
                contactSources[firstname.toLowerCase()] = source
            }
        })
        
        // Clear current content
        this.el.innerHTML = ""
        
        // Split by @mentions and render
        const parts = message.split(/(@\w+)/g)
        parts.forEach(part => {
            if (part.startsWith("@") && part.length > 1) {
                // Get the name without @
                const name = part.substring(1)
                const lowerName = name.toLowerCase()
                
                // Determine styling based on source
                const source = contactSources[lowerName]
                let sourceClass = "bg-blue-100 text-blue-800 border-blue-200"
                
                if (source === "hubspot") {
                    sourceClass = "bg-orange-100 text-orange-700 border-orange-200"
                } else if (source === "salesforce") {
                    sourceClass = "bg-blue-100 text-blue-800 border-blue-200"
                }
                
                // Create styled mention badge
                const span = document.createElement("span")
                span.className = `${sourceClass} px-2 py-0.5 rounded-full text-xs font-medium border`
                span.contentEditable = "false"
                span.textContent = name
                span.dataset.mentionName = name
                this.el.appendChild(span)
            } else if (part) {
                // Regular text
                const textNode = document.createTextNode(part)
                this.el.appendChild(textNode)
            }
        })
    },
    
    checkForMention() {
        const selection = window.getSelection()
        
        if (selection.rangeCount === 0) {
            this.clearMention()
            return
        }
        
        const range = selection.getRangeAt(0)
        
        // Get text before cursor by looking at the actual DOM
        let textBeforeCursor = ""
        let node = range.startContainer
        let offset = range.startOffset
        
        // Build text from all preceding nodes
        const allTextNodes = []
        const walker = document.createTreeWalker(this.el, NodeFilter.SHOW_TEXT)
        let currentNode
        while (currentNode = walker.nextNode()) {
            allTextNodes.push(currentNode)
        }
        
        // Find the node containing the cursor and build text before it
        let foundCursorNode = false
        for (const textNode of allTextNodes) {
            if (textNode === node) {
                textBeforeCursor += textNode.textContent.substring(0, offset)
                foundCursorNode = true
                break
            } else {
                textBeforeCursor += textNode.textContent
            }
        }
        
        // If cursor is not in a text node (e.g., at end after a span), count all text
        if (!foundCursorNode) {
            textBeforeCursor = this.getPlainText()
        }
        
        // Find the last @ before cursor
        const lastAtIndex = textBeforeCursor.lastIndexOf("@")
        
        if (lastAtIndex === -1) {
            this.clearMention()
            return
        }
        
        const textAfterAt = textBeforeCursor.substring(lastAtIndex + 1)
        
        // Check if this @ is part of an existing complete mention (word boundary after alphanumeric)
        // Look for pattern: @Word followed by space or end
        const completedMentionPattern = /^\w+\s/
        if (completedMentionPattern.test(textAfterAt)) {
            // This is a completed mention (e.g., "@Prabhas "), don't search
            this.clearMention()
            return
        }
        
        // Also clear if there's multiple words (user typed past the mention)
        if (textAfterAt.includes(" ") && textAfterAt.trim().includes(" ")) {
            this.clearMention()
            return
        }
        
        // If no text after @, don't search yet
        if (textAfterAt.length === 0) {
            this.clearMention()
            return
        }
        
        // Only search if text after @ is a valid mention query (alphanumeric only, no spaces)
        // And it's not a complete word that already has a space after it
        const queryText = textAfterAt.split(/\s/)[0] // Get text up to first space
        if (/^\w+$/.test(queryText) && queryText.length > 0) {
            this.mentionQuery = queryText
            this.mentionStartPos = lastAtIndex
            this.pushEvent("mention_search", { query: this.mentionQuery })
        } else {
            this.clearMention()
        }
    },
    
    getPlainText() {
        // Get plain text, converting mention badges back to @name
        let text = ""
        const walker = document.createTreeWalker(this.el, NodeFilter.SHOW_TEXT | NodeFilter.SHOW_ELEMENT)
        let node
        let lastWasMention = false
        
        while (node = walker.nextNode()) {
            if (node.nodeType === Node.TEXT_NODE) {
                // Ignore text nodes that are inside mention badges (since we handle the badge element itself)
                if (node.parentElement && node.parentElement.dataset.mentionName) {
                    continue
                }
                text += node.textContent
                lastWasMention = false
            } else if (node.nodeType === Node.ELEMENT_NODE && node.dataset.mentionName) {
                // Add @mention - include space after if there isn't one already
                const mentionText = "@" + node.dataset.mentionName
                text += mentionText
                lastWasMention = true
            }
        }
        
        return text
    },
    
    getCharacterOffset(range) {
        let offset = 0
        const preCaretRange = range.cloneRange()
        preCaretRange.selectNodeContents(this.el)
        preCaretRange.setEnd(range.endContainer, range.endOffset)
        offset = preCaretRange.toString().length
        return offset
    },
    
    saveCursorPosition() {
        const selection = window.getSelection()
        if (selection.rangeCount > 0) {
            return this.getCharacterOffset(selection.getRangeAt(0))
        }
        return 0
    },
    
    restoreCursorPosition(offset) {
        const range = document.createRange()
        const selection = window.getSelection()
        
        // Find the text node and offset
        let currentOffset = 0
        const walker = document.createTreeWalker(this.el, NodeFilter.SHOW_TEXT)
        let node
        
        while (node = walker.nextNode()) {
            const nodeLength = node.textContent.length
            if (currentOffset + nodeLength >= offset) {
                // Found the right node
                range.setStart(node, offset - currentOffset)
                range.collapse(true)
                selection.removeAllRanges()
                selection.addRange(range)
                return
            }
            currentOffset += nodeLength
        }
        
        // If we get here, place cursor at the end
        range.selectNodeContents(this.el)
        range.collapse(false)
        selection.removeAllRanges()
        selection.addRange(range)
    },
    
    syncToLiveView() {
        const text = this.getPlainText()
        
        // Debounce the sync
        clearTimeout(this.syncTimeout)
        this.syncTimeout = setTimeout(() => {
            // Extract mention names (without @)
            const mentions = []
            const mentionRegex = /@(\w+)/g
            let match
            while ((match = mentionRegex.exec(text)) !== null) {
                mentions.push(match[1])
            }
            
            this.pushEvent("sync_mentions", {
                message: text,
                mentions: mentions
            })
        }, 200)
    },
    
    clearMention() {
        this.mentionQuery = ""
        this.mentionStartPos = -1
        this.pushEvent("clear_mention_search", {})
    }
}

Hooks.ScrollToBottom = {
    mounted() {
        this.scrollToBottom()
    },
    
    updated() {
        this.scrollToBottom()
    },
    
    scrollToBottom() {
        this.el.scrollTop = this.el.scrollHeight
    }
}

export default Hooks
