module DiasporaFederation
  module WebFinger
    ##
    # The WebFinger document used for Diaspora* user discovery is based on an older
    # draft of the specification you can find in the wiki of the "webfinger" project
    # on {http://code.google.com/p/webfinger/wiki/WebFingerProtocol Google Code}
    # (from around 2010).
    #
    # In the meantime an actual RFC draft has been in development, which should
    # serve as a base for all future changes of this implementation.
    #
    # @example Creating a WebFinger document from account data
    #   wf = WebFinger.from_person({
    #     acct_uri:    "acct:user@server.example",
    #     alias_url:   "https://server.example/people/0123456789abcdef",
    #     hcard_url:   "https://server.example/hcard/users/0123456789abcdef",
    #     seed_url:    "https://server.example/",
    #     profile_url: "https://server.example/u/user",
    #     atom_url:    "https://server.example/public/user.atom",
    #     salmon_url:  "https://server.example/receive/users/0123456789abcdef",
    #     guid:        "0123456789abcdef",
    #     pubkey:      "-----BEGIN PUBLIC KEY-----\nABCDEF==\n-----END PUBLIC KEY-----"
    #   })
    #   xml_string = wf.to_xml
    #
    # @example Creating a WebFinger instance from an xml document
    #   wf = WebFinger.from_xml(xml_string)
    #   ...
    #   hcard_url = wf.hcard_url
    #   ...
    #
    # @see http://tools.ietf.org/html/draft-jones-appsawg-webfinger "WebFinger" -
    #   current draft
    # @see http://code.google.com/p/webfinger/wiki/CommonLinkRelations
    # @see http://www.iana.org/assignments/link-relations/link-relations.xhtml
    #   official list of IANA link relations
    class WebFinger
      private_class_method :new

      # The Subject element should contain the webfinger address that was asked
      # for. If it does not, then this webfinger profile MUST be ignored.
      attr_reader :acct_uri

      # Link to the users profile
      attr_reader :alias_url, :profile_url

      # Link to the +hCard+
      attr_reader :hcard_url

      # Link to the pod
      attr_reader :seed_url

      # This atom feed is an Activity Stream of the user's public posts. Diaspora
      # pods SHOULD publish an Activity Stream of public posts, but there is
      # currently no requirement to be able to read Activity Streams.
      # @see http://activitystrea.ms/ Activity Streams specification
      #
      # Note that this feed MAY also be made available through the PubSubHubbub
      # mechanism by supplying a <link rel="hub"> in the atom feed itself.
      attr_reader :atom_url

      # The salmon endpoint URL
      # @see http://salmon-protocol.googlecode.com/svn/trunk/draft-panzer-salmon-00.html#SMLR
      #   Panzer draft for Salmon, paragraph 3.3
      attr_reader :salmon_url

      # @deprecated Either convert these to +Property+ elements or move to the
      #   +hCard+, which actually has fields for an +UID+ defined in the +vCard+
      #   specification (will affect older Diaspora* installations).
      #
      # This is just the guid. When a user creates an account on a pod, the pod
      # MUST assign them a guid - a random hexadecimal string of at least 8
      # hexadecimal digits.
      attr_reader :guid

      # @deprecated Either convert these to +Property+ elements or move to the
      #   +hCard+, which actually has fields for an +KEY+ defined in the +vCard+
      #   specification (will affect older Diaspora* installations).
      #
      # When a user is created on the pod, the pod MUST generate a pgp keypair
      # for them. This key is used for signing messages. The format is a
      # DER-encoded PKCS#1 key beginning with the text
      # "-----BEGIN PUBLIC KEY-----" and ending with "-----END PUBLIC KEY-----".
      attr_reader :pubkey

      # +hcard_url+ link relation
      REL_HCARD = "http://microformats.org/profile/hcard"

      # +seed_url+ link relation
      REL_SEED = "http://joindiaspora.com/seed_location"

      # @deprecated This should be a +Property+ or moved to the +hCard+, but +Link+
      #   is inappropriate according to the specification (will affect older
      #   Diaspora* installations).
      # +guid+ link relation
      REL_GUID = "http://joindiaspora.com/guid"

      # +profile_url+ link relation.
      # @note This might just as well be an +Alias+ instead of a +Link+.
      REL_PROFILE = "http://webfinger.net/rel/profile-page"

      # +atom_url+ link relation
      REL_ATOM = "http://schemas.google.com/g/2010#updates-from"

      # +salmon_url+ link relation
      REL_SALMON = "salmon"

      # @deprecated This should be a +Property+ or moved to the +hcard+, but +Link+
      #   is inappropriate according to the specification (will affect older
      #   Diaspora* installations).
      # +pubkey+ link relation
      REL_PUBKEY = "diaspora-public-key"

      # Create the XML string from the current WebFinger instance
      # @return [String] XML string
      def to_xml
        doc = XrdDocument.new
        doc.subject = @acct_uri
        doc.aliases << @alias_url

        add_links_to(doc)

        doc.to_xml
      end

      # Create a WebFinger instance from the given account data Hash.
      # @param [Hash] data account data
      # @return [WebFinger] WebFinger instance
      # @raise [InvalidData] if the given data Hash is invalid or incomplete
      def self.from_person(data)
        raise InvalidData, "person data incomplete" unless account_data_complete?(data)

        wf = allocate
        wf.instance_eval {
          @acct_uri    = data[:acct_uri]
          @alias_url   = data[:alias_url]
          @hcard_url   = data[:hcard_url]
          @seed_url    = data[:seed_url]
          @profile_url = data[:profile_url]
          @atom_url    = data[:atom_url]
          @salmon_url  = data[:salmon_url]

          # TODO: change me!  #########
          @guid        = data[:guid]
          @pubkey      = data[:pubkey]
          #############################
        }
        wf
      end

      # Create a WebFinger instance from the given XML string.
      # @param [String] webfinger_xml WebFinger XML string
      # @return [WebFinger] WebFinger instance
      # @raise [InvalidData] if the given XML string is invalid or incomplete
      def self.from_xml(webfinger_xml)
        data = parse_xml_and_validate(webfinger_xml)

        hcard_url, seed_url, guid, profile_url, atom_url, salmon_url, pubkey = parse_links(data)

        wf = allocate
        wf.instance_eval {
          @acct_uri    = data[:subject]
          @alias_url   = data[:aliases].first
          @hcard_url   = hcard_url
          @seed_url    = seed_url
          @profile_url = profile_url
          @atom_url    = atom_url
          @salmon_url  = salmon_url

          # TODO: change me!  ##########
          @guid        = guid
          @pubkey      = Base64.strict_decode64(pubkey)
          ##############################
        }
        wf
      end

      private

      # Checks the given account data Hash for correct type and completeness.
      # @param [Hash] data account data
      # @return [Boolean] validation result
      def self.account_data_complete?(data)
        data.instance_of?(Hash) && data.key?(:acct_uri) &&
          data.key?(:alias_url) && data.key?(:hcard_url) &&
          data.key?(:seed_url) && data.key?(:guid) &&
          data.key?(:profile_url) && data.key?(:atom_url) &&
          data.key?(:salmon_url) && data.key?(:pubkey)
      end
      private_class_method :account_data_complete?

      # Parses the XML string to a Hash and does some rudimentary checking on
      # the data Hash.
      # @param [String] webfinger_xml WebFinger XML string
      # @return [Hash] data XML data
      # @raise [InvalidData] if the given XML string is invalid or incomplete
      def self.parse_xml_and_validate(webfinger_xml)
        data = XrdDocument.xml_data(webfinger_xml)
        valid = data.key?(:subject) && data.key?(:aliases) && data.key?(:links)
        raise InvalidData, "webfinger xml is incomplete" unless valid
        data
      end
      private_class_method :parse_xml_and_validate

      def add_links_to(doc)
        doc.links << {rel:  REL_HCARD,
                      type: "text/html",
                      href: @hcard_url}
        doc.links << {rel:  REL_SEED,
                      type: "text/html",
                      href: @seed_url}

        # TODO: change me!  ##############
        doc.links << {rel:  REL_GUID,
                      type: "text/html",
                      href: @guid}
        ##################################

        doc.links << {rel:  REL_PROFILE,
                      type: "text/html",
                      href: @profile_url}
        doc.links << {rel:  REL_ATOM,
                      type: "application/atom+xml",
                      href: @atom_url}
        doc.links << {rel:  REL_SALMON,
                      href: @salmon_url}

        # TODO: change me!  ##############
        doc.links << {rel:  REL_PUBKEY,
                      type: "RSA",
                      href: Base64.strict_encode64(@pubkey)}
        ##################################
      end

      def self.parse_links(data)
        links = data[:links]
        hcard   = parse_link(links, REL_HCARD)
        seed    = parse_link(links, REL_SEED)
        guid    = parse_link(links, REL_GUID)
        profile = parse_link(links, REL_PROFILE)
        atom    = parse_link(links, REL_ATOM)
        salmon  = parse_link(links, REL_SALMON)
        pubkey  = parse_link(links, REL_PUBKEY)
        raise InvalidData, "webfinger xml is incomplete" unless [hcard, seed, guid, profile, atom, salmon, pubkey].all?
        [hcard[:href], seed[:href], guid[:href], profile[:href], atom[:href], salmon[:href], pubkey[:href]]
      end
      private_class_method :parse_links

      def self.parse_link(links, rel)
        links.find {|l| l[:rel] == rel }
      end
      private_class_method :parse_link
    end
  end
end
