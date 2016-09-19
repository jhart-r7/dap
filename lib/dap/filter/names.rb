require 'set'

module Dap
module Filter

MATCH_FQDN = /^([a-z0-9\_\-]+\.)+[a-z0-9\-]+\.?$/


class FilterExtractHostname

  DEFAULT_VALID_FQDNS = Set.new(
    %w(
        AC AD AE AERO AF AG AI AL AM AN AO AQ AR ARPA AS ASIA AT AU AW AX AZ BA BB BD BE BF BG BH BI BIKE BIZ
        BJ BM BN BO BR BS BT BV BW BY BZ CA CAMERA CAT CC CD CF CG CH CI CK CL CLOTHING CM CN CO COM CONSTRUCTION
        CONTRACTORS COOP CR CU CV CW CX CY CZ DE DJ DK DM DO DZ EC EDU EE EG EQUIPMENT ER ES ESTATE ET EU FI FJ FK
        FM FO FR GA GALLERY GB GD GE GF GG GH GI GL GM GN GOV GP GQ GR GRAPHICS GS GT GU GURU GW GY HK HM HN
        HOLDINGS HR HT HU ID IE IL IM IN INFO INT IO IQ IR IS IT JE JM JO JOBS JP KE KG KH KI KM KN KP KR KW KY KZ
        LA LAND LB LC LI LIGHTING LK LR LS LT LU LV LY MA MC MD ME MG MH MIL MK ML MM MN MO MOBI MP MQ MR MS MT MU
        MUSEUM MV MW MX MY MZ NA NAME NC NE NET NF NG NI NL NO NP NR NU NZ OM ORG PA PE PF PG PH PK PL PLUMBING PM
        PN POST PR PRO PS PT PW PY QA RE RO RS RU RW SA SB SC SD SE SEXY SG SH SI SINGLES SJ SK SL SM SN SO SR ST
        SU SV SX SY SZ TATTOO TC TD TECHNOLOGY TEL TF TG TH TJ TK TL TM TN TO TP TR TRAVEL TT TV TW TZ UA UG UK US
        UY UZ VA VC VE VENTURES VG VI VN VOYAGE VU WF WS XN--3E0B707E XN--45BRJ9C XN--80AO21A XN--80ASEHDB
        XN--80ASWG XN--90A3AC XN--CLCHC0EA0B2G2A9GCD XN--FIQS8S XN--FIQZ9S XN--FPCRJ9C3D XN--FZC2C9E2C XN--GECRJ9C
        XN--H2BRJ9C XN--J1AMH XN--J6W193G XN--KPRW13D XN--KPRY57D XN--L1ACC XN--LGBBAT1AD8J XN--MGB9AWBF
        XN--MGBA3A4F16A XN--MGBAAM7A8H XN--MGBAYH7GPA XN--MGBBH1A71E XN--MGBC0A9AZCG XN--MGBERP4A5D4AR
        XN--MGBX4CD0AB XN--NGBC5AZD XN--O3CW4H XN--OGBPF8FL XN--P1AI XN--PGBS0DH XN--S9BRJ9C XN--UNUP4Y
        XN--WGBH1C XN--WGBL6A XN--XKC2AL3HYE2A XN--XKC2DL3A5EE0H XN--YFRO4I67O XN--YGBI2AMMX XXX YE YT ZA ZM ZW
      ))

  def initialize(*args)
    @iana_valid_fqdns = File.join(Dap::DATA_DIR, 'tlds-alpha-by-domain.txt')
    @valid_fqdns = DEFAULT_VALID_FQDNS
    if File.exists?(@iana_valid_fqdns)
      @valid_fqdns |= IO.readlines(@iana_valid_fqdns).map(&:rstrip).map(&:upcase)
      puts "loaded"
    end
    super(*args)
  end

  include BaseDecoder
  def decode(data)
    data = data.strip.gsub(/.*\@/, '').gsub(/^\*+/, '').gsub(/^\.+/, '').gsub(/\.+$/, '').downcase
    return unless data =~ MATCH_FQDN

    return unless @valid_fqdns.include?(data.split('.').last.upcase)

    { 'hostname' => data }
  end
end

class FilterSplitDomains
  include Base
  def process(doc)
    lines = [ ]
    self.opts.each_pair do |k,v|
      if doc.has_key?(k)
        expand(doc[k]).each do |line|
          lines << doc.merge({ "#{k}.domain" => line })
        end
      end
    end
   lines.length == 0 ? [ doc ] : [ lines ]
  end

  def expand(data)
    names = []
    bits  = data.split('.')
    while (bits.length > 1)
      names << bits.join('.')
      bits.shift
    end
    names
  end
end


class FilterPrependSubdomains
  include Base
  def process(doc)
    lines = [ ]
    self.opts.each_pair do |k,v|
      if doc.has_key?(k)
        expand(doc[k], v).each do |line|
          lines << doc.merge({ k => line })
        end
      end
    end
   lines.length == 0 ? [ ] : [ lines ]
  end

  def expand(data, names)
    outp = [ data ]
    bits = data.split(".")
    subs = names.split(",")

    # Avoid www.www.domain.tld and mail.www.domain.tld
    return outp if subs.include?(bits.first)
    subs.each do |sub|
      outp << "#{sub}.#{data}"
    end

    outp
  end

end

#
# Acts like SplitDomains but strips out common dynamic IP RDNS formats
#
# XXX - Lots of work left to do
#

class FilterSplitNonDynamicDomains
  include Base
  def process(doc)
    lines = [ ]
    self.opts.each_pair do |k,v|
      if doc.has_key?(k)
        expand(doc[k]).each do |line|
          lines << doc.merge({ "#{k}.domain" => line })
        end
      end
    end
   lines.length == 0 ? [ doc ] : [ lines ]
  end

  def expand(data)
    names = []
    data  = data.unpack("C*").pack("C*").
      gsub(/.*ip\d+\.ip\d+\.ip\d+\.ip\d+\./, '').
      gsub(/.*\d+[\_\-\.x]\d+[\_\-\.x]\d+[\_\-\.x]\d+[^\.]+/, '').
      gsub(/.*node-[a-z0-9]+.*pool.*dynamic\./, '').
      gsub(/.*[a-z][a-z]\d+\.[a-z]as[a-z0-9]+\./, '').
      # cl223.001033200.technowave.ne.jp
      gsub(/^cl\d+.[0-9]{6,14}\./, '').
      # n157.s1117.m-zone.jp
      gsub(/^n\d+.s\d+\.m-zone.jp/, 'm-zone.jp').
      # u570054.xgsnu2.imtp.tachikawa.mopera.net
      # s505207.xgsspn.imtp.tachikawa.spmode.ne.jp
      gsub(/^[us]\d+.xgs[a-z0-9]+\.imtp/, 'imtp').
      # tzbm6501209.tobizaru.jp
      gsub(/^tzbm[0-9]{6,9}\./, '').
      # ARennes-556-1-256-bdcst.w2-14.abo.wanadoo.fr
      gsub(/.*\-\d+\-\d+\-\d+\-(net|bdcst)\./, '').
      # bl19-128-119.dsl.telepac.pt
      gsub(/.*\d+\-\d+\-\d+\.dsl/, 'dsl').
      gsub(/.*pool\./, '').
      gsub(/.*dynamic\./, '').
      gsub(/.*static\./, '').
      gsub(/.*dhcp[^\.]+\./, '').
      gsub(/^\d{6,100}\./, '').
      gsub(/^\.+/, '').
      tr('^a-z0-9.-', '')

    bits  = data.split('.')
    while (bits.length > 1)
      names << bits.join('.')
      bits.shift
    end
    names
  end
end


end
end
