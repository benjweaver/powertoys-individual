param(
    [string[]]$Apps = @('Awake'),
    [switch]$List,
    [switch]$Uninstall,
    [switch]$NoStartup,
    [switch]$NoLaunch,
    [string]$InstallRoot = (Join-Path $env:LOCALAPPDATA 'PowerToysIndividual'),
    [string]$PackageDirectory
)
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$repository='benjweaver/powertoys-individual'
$release='v0.2.0'
# BEGIN CATALOG
$releaseCatalog = @'
{
  "Awake": {
    "notes": "Starts Off at sign-in; uses native tray menu.",
    "arm64": {
      "archive": "f9a95769ed70041e014ba2f7549d7aa994e6ccb5fad70b88874a1d1d42b6d06d",
      "manifest": "1edd755b456588b04701ef4929e0188428e422bd254d78a1fe325ed0f82b0287"
    },
    "x64": {
      "archive": "b7435ffd4d907c2c1699a9e7357a1f07cf897af0b0173a3d19275a961f10d5b9",
      "manifest": "6bf3f373326928fd5e90c4894014fb68b3da3e8c5cbf1ae87746c45e339a3be7"
    }
  },
  "AdvancedPaste": {
    "notes": "AI features need separately configured providers; local formats do not.",
    "arm64": {
      "archive": "49ad0e85f1a0ecbff935059a7552081074f065d0b8750f42080c3d3b945b3b7b",
      "manifest": "a5926c7571f44985601fdbedd674cddccda406b67142d474bec406efdfac487b"
    },
    "x64": {
      "archive": "b5b272f5de582301118a72a5d64cd5b36cd38fa41802632941491909ef0004f5",
      "manifest": "bbb544037297f46a12917e746a0437c79bc0f6896db57b888f00e4142964dc0c"
    }
  },
  "AlwaysOnTop": {
    "notes": "",
    "arm64": {
      "archive": "945691ac06286ce9e71cfef727b9b1c44ffb51c40cd010ba94989111d1c0db81",
      "manifest": "cd5127b83b75e86d72a552f3b258a67aa32f2aa5d1cad960862ac732cac02606"
    },
    "x64": {
      "archive": "d0f78d23e684e79304a230c935688a3b4103f9903559aa6a32c297f01a6454df",
      "manifest": "db67b99839805fbed5eb225f49d815c2623b250af50af048599aa09ee5888221"
    }
  },
  "ColorPicker": {
    "notes": "",
    "arm64": {
      "archive": "8fd9fc33096c906051ffbe86c5fd351a4e735a9f1f1c7a0cb41b4acc30453162",
      "manifest": "92298aa1bfab52eaed7513e600b8d3c51bf053637eefdfca191bb19490a9788d"
    },
    "x64": {
      "archive": "163a571ae12cfe3a913718f3203e8b76106b911690ba4d98d940fc913b438359",
      "manifest": "398511aa09619ed5f79cfa2560bce6daef8be4849d0135dc3d72621717ebc617"
    }
  },
  "CommandNotFound": {
    "notes": "Uses Microsoft.WinGet.CommandNotFound in PowerShell 7; installs its own profile entry.",
    "arm64": {
      "archive": "b15214dff81e9a39f084711886a4ef98a9bbdf3ad3d1f674828e880bfa2073c7",
      "manifest": "4ccb8433ac77d3fce07a91d16dbcc10a7f67250306a7f3d05998578d12995ee1"
    },
    "x64": {
      "archive": "9c9a3f1f59993648811d7dc060aa316646a2257affad6a6f17c86a502e5fd661",
      "manifest": "ee0134a1c38d4abaf7aadadcfb35014422ae862114914d8657a83cc5962a28a1"
    }
  },
  "CommandPalette": {
    "notes": "Registers only Microsoft Command Palette and its framework dependency as per-user AppX packages.",
    "arm64": {
      "archive": "06c4886dbe58085897871424183fc5fc642820f49797982fa59a04a3f16a988e",
      "manifest": "0338e91a7b4e961d38f759fce2ef4a3e02d62a288717443add9768668a2e2e90"
    },
    "x64": {
      "archive": "8f69b8301772fbb9a5b5ff5e2051528ff5148eb076ba17553e6f912fd199b8c7",
      "manifest": "808d99052682aaeae7f3ddb498119faaa49264b0f3ca639e28c0271f37c69764"
    }
  },
  "CropAndLock": {
    "notes": "",
    "arm64": {
      "archive": "e4e9063bd652481c466c2803a5abb4bf0f411f1356492c343bd43036d3bb5d44",
      "manifest": "635a4238ab1a4b8e607e228da6bc57407ad98b07e6e6153b36753380be4eb797"
    },
    "x64": {
      "archive": "bb6232cb03a4abd8cf460c6429ac985c5a9f65ad5fdca70224c00e14605203a6",
      "manifest": "98d381c70fd6cb6f1932a47c3e51a186a91c62303ceddcd0a21f194658c0b97e"
    }
  },
  "EnvironmentVariables": {
    "notes": "",
    "arm64": {
      "archive": "10c87597da31fbcf157e0a0068e94f86b1391382fdc8cdb1d0ba1c23f767cef8",
      "manifest": "9bdeb00d4e9146b65b4b3ac2beb88a2bb20a9e4ae722fddf10d74cfc677baae5"
    },
    "x64": {
      "archive": "71ce143b1bb5de52f2d8ef7ca484a3dbd4010b89ca9f613829237650d7885dc5",
      "manifest": "e6d7252bd321f910dfbe6b3c135b46ca56cea32334dd1c2e4c9b495db1913625"
    }
  },
  "FancyZones": {
    "notes": "Multi-monitor behavior needs physical hardware validation.",
    "arm64": {
      "archive": "3e21e71f91802fe7773b4ccb140cc9b9d2ec32a1ff262e3bd9bdbf9938b95a05",
      "manifest": "f5eed5f8189a0ee6ca4ff3b6ecd978159788ef285fae27b1436b24fd4e414f15"
    },
    "x64": {
      "archive": "7284e2c24847317c782d6201ceb47bf9907035616588a29008a8717a44801813",
      "manifest": "f979632eb78b69e06983a46b6408b3b156333a187d0ecf6a6fb7a75639a8afc5"
    }
  },
  "FileExplorerAddons": {
    "notes": "Per-user preview/thumbnail registration; Explorer may need to reopen.",
    "arm64": {
      "archive": "bfd03011eedaf252c94c4de21c8b889ec2d01920ee05acde0d3614834f4148a2",
      "manifest": "d95a5060c07f51c9336ae99df6a48124feb620a14f08a09e29469b813d1f155b"
    },
    "x64": {
      "archive": "984578bd44bfe2c2f799280450c799f568a1374365f38ebcedf9766b790e1950",
      "manifest": "0f16405b2927428f3dfe5f973717a3dadd1bb9b815962609321f21b01fd240f4"
    }
  },
  "FileLocksmith": {
    "notes": "",
    "arm64": {
      "archive": "c89a9c3d56b1aed269428814d9928645e91c3b93adf3c1d10097b7e9e53c8757",
      "manifest": "319d59fd767894aa214a3f4ad20d051a3ccf61adc76b342d86e13fb6f9efe884"
    },
    "x64": {
      "archive": "e0fcbb87f1d6b00eab3a0590da9f511d47798edcef64351ae78fde846d69ecbf",
      "manifest": "87efb7ab026ccd4406ce76f3dadf443a103c86c523ed78a26ab7d520eb572231"
    }
  },
  "GrabAndMove": {
    "notes": "",
    "arm64": {
      "archive": "3db778918a57a6a6fa5434a088654b55322be855c1a2f394041f5c24de7fcbf0",
      "manifest": "0c4eab71849f72717497d7a1273fa70a12af5c7971bb4ec7c23c2c461d26f938"
    },
    "x64": {
      "archive": "08633e97d5f04124a1106a5a8990b8ee1359644eab83998b7997e0a60e93e7f1",
      "manifest": "b913d4e16c759f33e77e45dc3f95d70ab2107bf5675a95de47ce65355892b4d5"
    }
  },
  "Hosts": {
    "notes": "Editing the system hosts file requires elevation.",
    "arm64": {
      "archive": "57c16e81d5342d2211aead8f5e9962b7f018f131bad28b6060d5fb2974d038f2",
      "manifest": "46f276582433894e3c27f81b8e915c2ea157bea3e4138d7fa4e3290c6e1e428b"
    },
    "x64": {
      "archive": "b7d22d8bb598ebeb101766a5138f4a6e2c1271c41c3d63e086bfd5cc08f8e321",
      "manifest": "03a4056204113d7751a9061c305a796cbd976ede110b9ea203841b8ffb38ac31"
    }
  },
  "ImageResizer": {
    "notes": "",
    "arm64": {
      "archive": "2710ac74e5e48f1f8aa9b97bf51662f238dba00baee8f48a6da13ceca31019f8",
      "manifest": "c7b84b28995b136a7669f27443d93833c1188ff3b6541c8d404bbaf19dd34a21"
    },
    "x64": {
      "archive": "2264dcc261782af7f0273a3a204f6825bddfd3520371b56e81c9c48eec28c7c6",
      "manifest": "f385856d248be36ccdeddd1380868c990429ef27c0c9c39293635f9a2c026e5c"
    }
  },
  "KeyboardManager": {
    "notes": "",
    "arm64": {
      "archive": "9dafc2b28d0eb449ee94a124303cee2d56c8886cac24e8a9698fb7ed1a26b74c",
      "manifest": "2b42539a95fc473a04b6d5005cccc5c41f79f5b28d575ef9bf5d1e9dac56b427"
    },
    "x64": {
      "archive": "55ed089743f7f3a5ae78dc05404190e89de99073437b2383770a1038bdd59b8e",
      "manifest": "4e33a6fc2997bfda2a2b6ffb03ea91dfba72acbfd3947fcc91f2ecf089509bcd"
    }
  },
  "LightSwitch": {
    "notes": "",
    "arm64": {
      "archive": "d66ac4050e5031f1d2cb62a3fbcc39c5720f3bfe3b320ef997086042fd4ab4f8",
      "manifest": "afd2ce92a8ac6d4174321200eb91b73e91ffcfc69ab92230bcb4937cf4198ea5"
    },
    "x64": {
      "archive": "65d3df0d14a782874d7ef768e7ca85bfcdf30c41a762fee72e7080786c4e52a6",
      "manifest": "db1f2936b4ca2b5685de5bc35fea464cad7b766e4997fa215929cc5ba841e7e7"
    }
  },
  "MouseUtilities": {
    "notes": "",
    "arm64": {
      "archive": "0466a13aab1001736715080a9ca6ce3439083d8fb0733e97a6957156ac126a30",
      "manifest": "125fe5873a8f865d7cdb1ecf49cc0a46ac3521df44ae6637a1e7954e32c9792f"
    },
    "x64": {
      "archive": "c08ec7f9e6430c76a6fe44b55834fc7310d2cea2d473c8534e565a5d937acb5b",
      "manifest": "97306fc6e481626a214de4f60f967335768fcc86407eb9c8100589f74d9558f5"
    }
  },
  "FindMyMouse": {
    "notes": "",
    "arm64": {
      "archive": "5b67f3bf14ee5f6f8ed2ae03a9cb9c5ebcb78ff45595cbf1f5e56378969dde16",
      "manifest": "3b5178c33291bb99c8394e0cb290070f8c61db0d52a62ec0cf9efa5e891a99fd"
    },
    "x64": {
      "archive": "672b1c9cbe2708c9723e3d2ff0ad673cbe7141d1972bda644c86256f04c5c62d",
      "manifest": "497eea939d6d035e0a28d2c197f087e059abddfe7a4703fee44547f0a7a7d4b9"
    }
  },
  "MouseHighlighter": {
    "notes": "",
    "arm64": {
      "archive": "893c092c02610a0fea9106390f65547d16d9a12a8437add49e0660817553d8ed",
      "manifest": "5e5c7d91f24a8105c14a5e3bf3bab58c6d20fbd90fb321cbd4a7568951db8c9b"
    },
    "x64": {
      "archive": "3b70bd8de259f1f464cf01efa5dad6e4794c6f2d304b452f95c040a3a0749670",
      "manifest": "34ec197b6edbaebe6a9c0b061c9dfed17f57c06714c3c319a0bf5feb763b7c86"
    }
  },
  "MouseJump": {
    "notes": "",
    "arm64": {
      "archive": "01dff7344cbe1d186b3f064f7a9afc1ffaf18e5a06c1bc21fb14992d9c1a5cd8",
      "manifest": "b875f6805c8457a9b3563c2f40eb7017687b6e862ced98405236679af438ce77"
    },
    "x64": {
      "archive": "eb4e582dbb3b2a9d1a6a1e41931b10ced49e6955d0dc751a4c2a1b631fb7671d",
      "manifest": "b0ed96798457b30c4bd26f50d414ef811cd373d918da5987f984b74f329fd64f"
    }
  },
  "MousePointerCrosshairs": {
    "notes": "",
    "arm64": {
      "archive": "8d938fb572065954e20106237316fb365544b098a5b21d6946356a9dbcf16b9d",
      "manifest": "30508a7d6a60da0bead2a4cd19aad3bd17990cf4b9d716405fcc7a2470bea785"
    },
    "x64": {
      "archive": "d91dcb2f8ed893ecdc8cf98d1e209294cbdbebb4e22712aa34f59ef6f7fdb08d",
      "manifest": "a94714a760cdb3c7e4afc2b83cd22d461acec2d5e0aaf3df592b2683209deb00"
    }
  },
  "CursorWrap": {
    "notes": "",
    "arm64": {
      "archive": "5cd2c87de3978b77cd5b59b3761c777482579ebc7b24f4b00bbb76d8d9d04640",
      "manifest": "f876f0dac9077c35fd68c005015b8e3314377a0d35422fe85fb93b604147ff3a"
    },
    "x64": {
      "archive": "bcd9442ce90daaddb645cef0299b219edcfae98ebb8e9e4dea94de130a00ebab",
      "manifest": "d5585f7dca6cb9610dcc51675ba81cf026ab01cb48ca8158ae23dd8eb51f0c8d"
    }
  },
  "MouseWithoutBorders": {
    "notes": "Network sharing requires two physical PCs and Windows firewall configuration; not validated by one VM.",
    "arm64": {
      "archive": "6c84025ac581b951e62b40fbb3c43d7866f4f22feb7f55f0659a56f65a2bc7b4",
      "manifest": "e4d47ee850b8ad7cedccf20802f5fa0dc44a3760572308773f1f9f25f6430d5a"
    },
    "x64": {
      "archive": "1dec82c0b9d51319d1649ea69eb54773276a7fd3d5eb028d87f2665297d05dc6",
      "manifest": "d08439d0926ab83135ba0a123b5969bd4ecb09f493aa681bcfb25de8700ab9c2"
    }
  },
  "NewPlus": {
    "notes": "Native New+ per-user Explorer context menu registration.",
    "arm64": {
      "archive": "fc685addfb513f26c8b05d2788611a94eeaaeac83ac842760b4854f7fe0e4f94",
      "manifest": "8dfa5f07c03b0527fe36cb32d23ea5d065feec9f3e75d2717a5d2021f058af6a"
    },
    "x64": {
      "archive": "7d812306c9e1cdce3cd42dc9d438913f7c6e568f166c6bdb9ecacfd9abc51a97",
      "manifest": "07846ce81fd2308a45745d6cbc6f1ffce646afc0763be4ae640d3909aacba421"
    }
  },
  "Peek": {
    "notes": "",
    "arm64": {
      "archive": "e80e4bbe788b033b0f7fef76b40087f35119be594281ebca1de093a842cc3a84",
      "manifest": "e23d8065b89808c2b4d508dc3813e5e58dc80cd7fb935cedf0775acc8eec9ed8"
    },
    "x64": {
      "archive": "22f89ed99611d02e432f626e55f450be30f8bbf24ec02792e138aa62f6e83295",
      "manifest": "434c80e03a8095b5f28496430736b4afda55c860de0805b30dd4641bc7bc8a4b"
    }
  },
  "PowerDisplay": {
    "notes": "Brightness/DDC controls need a supported physical display.",
    "arm64": {
      "archive": "a3dd19398da96e284eae17e4dc7470e68f9ad308d487ec1f61c13212349b172c",
      "manifest": "2b887afe5d8a96a7c492ed4abf1e16b0b0bd0de5324e0b6e12f30e065ac14d5d"
    },
    "x64": {
      "archive": "24f8b7f1fe2aa231eb225aa6fb5b57abc6566a278ba5b1b7a5bd4f8007b4b500",
      "manifest": "4a2e24175e91f80e90a671da951d056aefaf6c35b3ccc5ba2452a9f0825c2ae3"
    }
  },
  "PowerRename": {
    "notes": "",
    "arm64": {
      "archive": "c5055cfe22045f6da94221413bd3d2c228a8ea8859d6e54f3670fc0a803606d3",
      "manifest": "d574a5707f4687b2aa17fb9fb9c9027469f5993847b755ec9f6c953fc12982d2"
    },
    "x64": {
      "archive": "4dddb098c25ae2aac00241845c4fa3c3650857086bc560142faa85fc066e8adf",
      "manifest": "b6db96f4c168139bfcb5ab2762c6631c7784d5e908d951f310aa4ba8cb670913"
    }
  },
  "PowerToysRun": {
    "notes": "The PowerToys plugin only exposes installed utilities; no full-suite runner is installed.",
    "arm64": {
      "archive": "5424d4f1084a6b54b8356cfafdc6e7462c24a7efe9092d24e7d358c97c667f3b",
      "manifest": "f4f56a2c337874f70d5bccdbd10e7e306276b758bd961cf509572ad85d9f5ad1"
    },
    "x64": {
      "archive": "6f605511447b56697f898a3b83c2bac4fa669f40b4fe2bdc9dd77672d503d5e6",
      "manifest": "b94fc64d38d1ac701339ad1fd5288d65b12d67c58f72369b53b72fd423ad667c"
    }
  },
  "QuickAccent": {
    "notes": "",
    "arm64": {
      "archive": "2e36ac85f491067c809fad7e45474e47ee71b24dbd446152fc3099078ab97331",
      "manifest": "89067ed71f26044add15509bd80892308becf2821331a9884087beddd7ba1a34"
    },
    "x64": {
      "archive": "bffa63d09d81c0c642c9a5ee1c1396e991fb72564a1afbc0a2b0b73885a1705c",
      "manifest": "95a0954000256e3d9c4835df121111ea0ddeb64475cbd240617d7f305edd9b46"
    }
  },
  "RegistryPreview": {
    "notes": "",
    "arm64": {
      "archive": "a101d0f6c1859a64c06df9796c51244b812476ea8fbe2e6291d844a4cb0fc7a4",
      "manifest": "3577cd34ccdb62053199bb5a4940432fc0a47f4246741c19e708ccde7daf5165"
    },
    "x64": {
      "archive": "d537f80d060a298157f4dc5e4b2b53fd29b4f80f7d0eaaa045284d95f44b0e0a",
      "manifest": "f527cc4b3a24c2711d7143126601a1c9c9b7885d1e0bc907e15c05cd29501dab"
    }
  },
  "ScreenRuler": {
    "notes": "",
    "arm64": {
      "archive": "06d34db19066b8a0de441c8fd9ffd46c22d7356e4ee9bb59e2fe0399fb4c9633",
      "manifest": "f1fcaae6b491e830faa718dc41722fc662fc9b6664107b7905403f5b3842fe83"
    },
    "x64": {
      "archive": "57e5d9c6dde56b9a549da1c5a8d1824facd2ed553e42e36bbd683bcde6b3962f",
      "manifest": "478b402dbaebd56326d7971fb5a1ef4c47a8df4cc54696c8242d3df9b8883976"
    }
  },
  "ShortcutGuide": {
    "notes": "",
    "arm64": {
      "archive": "031416194307de3d5f8c28dd85c26095a5188d233b7f30530971dc829dd194f4",
      "manifest": "5940fd890dafddfff7b949468647c47f097d158e31b49a79c0e28c5ad313d7d4"
    },
    "x64": {
      "archive": "31a8aa07b083207928755aeb134539e73869955213acf614228fcbf58ec094f4",
      "manifest": "2d73c3227248abb2021b541478a54bf1e4b468f11ae85785902a2cced56df794"
    }
  },
  "TextExtractor": {
    "notes": "",
    "arm64": {
      "archive": "3843c3ca3eb3a8e4b4565f0e95cb9f4045b89ee602beddc91fc7628151d804ca",
      "manifest": "e68365afdc76207ad98cd4ea715828352d61c260bf5a72e1eef81619799ebc43"
    },
    "x64": {
      "archive": "339445f9984f61deade8915d806fad12373265954567481a5ed599438c0c0f0d",
      "manifest": "b39bb16530a9554c69370d80e549482a67f3aa006bed4fa79f825bc4589fa96d"
    }
  },
  "WindowHopper": {
    "notes": "",
    "arm64": {
      "archive": "a08815fd3efb131c02b564d7fdd985da7b7eda5f61f4a11befc06a069b1d39f0",
      "manifest": "4417b673e28934e211b9d817832a2941befd55e0f7555381d7f0118725723b65"
    },
    "x64": {
      "archive": "55760e7cf6f6b2cd12902daf7c2543def5d4295a1db360802a08d1e8c1d07705",
      "manifest": "a5de1b8d71ab32ceada2667fe1fd04b9c3f3d1adc4d237a888b704cf3282cd32"
    }
  },
  "Workspaces": {
    "notes": "",
    "arm64": {
      "archive": "b1ddcc7d4ab4bdd7b7929c4002211fc6a2e6df014b782977272349a9aa163335",
      "manifest": "2ba92c8a3d1116b78eaaead3cfa12ac3866cc1e88c8ae3199374206fbd5789ba"
    },
    "x64": {
      "archive": "0c8246b2a8f0634dfac169fec3fb16a82ea179de9a89d6a007bbe11a3d659fc2",
      "manifest": "af4831db04d9c1650891760b96b4e5b4a9f601fc1706570beb8990714379cdd8"
    }
  },
  "ZoomIt": {
    "notes": "",
    "arm64": {
      "archive": "eb27ff19d41f4a6e51f9a8e150d21d3bb69370288a03447c6dbc185345a0a91b",
      "manifest": "90f37a821e12f8bd2c30448176ddd564eabee8b6c69cacb7ef3a6c760f3eda47"
    },
    "x64": {
      "archive": "5a1db6a150daba48a47b9feb2d17aa4adbbc853d88ff42d323e67e96350c11a2",
      "manifest": "1e3c17861104936cedf29b90a182ccf46ed2d36f9ed7401b7658c0eb16577234"
    }
  }
}
'@ | ConvertFrom-Json
$catalog=@{}
foreach($entry in $releaseCatalog.PSObject.Properties){$catalog[$entry.Name]=@{arm64=$entry.Value.arm64;x64=$entry.Value.x64;notes=$entry.Value.notes}}
# END CATALOG
if($List){
 $catalog.Keys | Sort-Object | ForEach-Object { [pscustomobject]@{App=$_;Notes=$catalog[$_].notes} } | Format-Table -Wrap
 return
}
if ($env:OS -ne 'Windows_NT') { throw 'This installer runs on Windows only.' }
function Normalize([string]$Name){ return ($Name.Trim() -replace '[\s_+\-]','').ToLowerInvariant() }
$names=@{}
foreach($key in $catalog.Keys){$names[(Normalize $key)]=$key}
foreach($alias in @{HostsFileEditor='Hosts';Run='PowerToysRun';PowerAccent='QuickAccent';PowerOCR='TextExtractor';MeasureTool='ScreenRuler';CmdPal='CommandPalette';New='NewPlus';FileExplorerAddOns='FileExplorerAddons'}.GetEnumerator()){$names[(Normalize $alias.Key)]=$alias.Value}
$selected=@($Apps | ForEach-Object { Normalize $_ } | Select-Object -Unique)
if(-not $selected.Count){throw 'Specify at least one app.'}
foreach($app in $selected){if($app -ne 'all' -and -not $names.ContainsKey($app)){throw "Unsupported app '$app'. Use -List to see available utilities."}}
$uninstallAll=$Uninstall -and ($selected -contains 'all')
if($selected -contains 'all'){$selected=@($catalog.Keys | Where-Object {$_ -notin @('FindMyMouse','MouseHighlighter','MouseJump','MousePointerCrosshairs','CursorWrap')} | ForEach-Object {Normalize $_})}
foreach($app in $selected){if(-not $names.ContainsKey($app)){throw "Unsupported app '$app'. Use -List to see available utilities."}}
$selected=@($selected | ForEach-Object {$names[$_]} | Select-Object -Unique)
if(-not $Uninstall -and $selected -contains 'MouseUtilities'){$selected=@($selected | Where-Object {$_ -notin @('FindMyMouse','MouseHighlighter','MouseJump','MousePointerCrosshairs','CursorWrap')})}
$architecture=[Environment]::GetEnvironmentVariable('PROCESSOR_ARCHITECTURE','Machine').ToLowerInvariant()
if($architecture -eq 'amd64'){$architecture='x64'}
if($architecture -notin @('arm64','x64')){throw "Unsupported Windows architecture: $architecture"}
$InstallRoot=[IO.Path]::GetFullPath($InstallRoot).TrimEnd('\')
if(Get-Process -Name PowerToys -ErrorAction SilentlyContinue){throw 'Exit the full PowerToys suite before installing individual utilities.'}
function Quote-PS([string]$Text){return "'"+$Text.Replace("'","''")+"'"}
if($Uninstall){
 if($uninstallAll){$selected=@($catalog.Keys)}
 foreach($app in $selected){
  $receiptPath=Join-Path $InstallRoot ($app+'-install.json')
  if(-not(Test-Path $receiptPath)){Write-Output "$app is not installed.";continue}
  $receipt=Get-Content $receiptPath -Raw | ConvertFrom-Json
  $directory=[IO.Path]::GetFullPath($receipt.path).TrimEnd('\')
  if($receipt.app -ne $app -or -not $directory.StartsWith((Join-Path $InstallRoot $app)+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Unsafe installation receipt.'}
  $script=Join-Path $directory 'Uninstall-App.ps1'
  if(-not(Test-Path $script)){throw "$app was installed with an older release. Upgrade it before using automatic uninstall."}
  & ([scriptblock]::Create([IO.File]::ReadAllText($script))) -PackageDirectory $directory -ExpectedApp $app
 }
 return
}

function Verify-Package([string]$Directory,[string]$App){
 $entry=$catalog[$App][$architecture]
 $manifestPath=Join-Path $Directory 'package.json'
 if(-not(Test-Path -LiteralPath $manifestPath -PathType Leaf)){throw "Package manifest is missing: $Directory. Move any user-added files out of this directory before reinstalling."}
 if((Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash.ToLowerInvariant() -ne $entry.manifest){throw 'Package manifest changed.'}
 $manifest=Get-Content $manifestPath -Raw | ConvertFrom-Json
 if($manifest.utility -ne $App -or $manifest.architecture -ne $architecture){throw 'Package identity/architecture mismatch.'}
 if(-not $manifest.files -or -not $manifest.launcher_files){throw 'Missing package inventory.'}
 foreach($file in $manifest.files.PSObject.Properties){
  $path=[IO.Path]::GetFullPath((Join-Path $Directory $file.Name))
  if(-not $path.StartsWith($Directory.TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Unsafe package inventory path.'}
  if((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() -ne $file.Value){throw "Package file changed: $($file.Name)"}
 }
 foreach($target in $manifest.signature_targets){
  $signature=Get-AuthenticodeSignature (Join-Path $Directory $target)
  if($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Subject -notmatch 'O=Microsoft Corporation'){throw "Invalid Microsoft signature: $target"}
 }
}
function Owned-Link([string]$Path,[string]$App){
 if(Test-Path $Path){
  $description=(New-Object -ComObject WScript.Shell).CreateShortcut($Path).Description
  if($description -ne ('PowerToys Individual '+$App)){throw "An unrelated shortcut uses this name: $Path"}
 }
}
function Save-Link([string]$Path,[string]$App,[string]$Directory,[string]$Arguments,[string]$Icon){
 Owned-Link $Path $App
 New-Item -ItemType Directory (Split-Path $Path) -Force | Out-Null
 $link=(New-Object -ComObject WScript.Shell).CreateShortcut($Path)
 $link.TargetPath=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
 $link.Arguments=$Arguments;$link.WorkingDirectory=$Directory;$link.IconLocation=$Icon;$link.Description='PowerToys Individual '+$App;$link.Save()
}
$temp=Join-Path $env:TEMP ('PowerToysIndividual-'+[Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory $temp | Out-Null
try{
 foreach($app in $selected){
  $name=$app+'-'+$architecture+'.zip';$archive=Join-Path $temp $name
  if($PackageDirectory){Copy-Item -LiteralPath (Join-Path $PackageDirectory $name) -Destination $archive}
  else{Invoke-WebRequest -Uri ('https://github.com/'+$repository+'/releases/download/'+$release+'/'+$name) -OutFile $archive -UseBasicParsing}
  if((Get-FileHash $archive -Algorithm SHA256).Hash.ToLowerInvariant() -ne $catalog[$app][$architecture].archive){throw 'Release archive SHA-256 mismatch.'}
  $expanded=Join-Path $temp $app
  Expand-Archive -LiteralPath $archive -DestinationPath $expanded
  $payload=Join-Path $expanded ($app+'-'+$architecture)
  Verify-Package $payload $app
  $destination=Join-Path $InstallRoot ($app+'\'+$release+'-'+$architecture)
  $key='HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\PowerToysIndividual-'+$app
  if(Test-Path $key){$existing=Get-ItemProperty $key;if(-not $existing.PowerToysIndividualOwner -or -not $existing.PowerToysIndividualOwner.StartsWith($InstallRoot+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Unrelated uninstall registration exists.'}}
  if(Test-Path $destination){Verify-Package $destination $app}
  else{New-Item -ItemType Directory (Split-Path $destination) -Force | Out-Null;Move-Item -LiteralPath $payload -Destination $destination}
  $receiptPath=Join-Path $InstallRoot ($app+'-install.json')
  $previous=if(Test-Path $receiptPath){Get-Content $receiptPath -Raw | ConvertFrom-Json}else{$null}
  if($app -eq 'CommandPalette' -and $previous -and $previous.app -eq $app -and $previous.path -ne $destination){
   $old=[IO.Path]::GetFullPath($previous.path)
   $state=Join-Path $old 'install-state.json'
   if($old.StartsWith((Join-Path $InstallRoot $app)+'\',[StringComparison]::OrdinalIgnoreCase) -and (Test-Path $state)){Copy-Item -LiteralPath $state -Destination (Join-Path $destination 'install-state.json')}
  }
  if($app -ne 'Awake'){& ([scriptblock]::Create((Get-Content (Join-Path $destination 'Setup-App.ps1') -Raw))) -PackageDirectory $destination}
  $launcher=Join-Path $destination $(if($app -eq 'Awake'){'Start-Awake.ps1'}else{'Start-App.ps1'})
  $command='& ([scriptblock]::Create((Get-Content -LiteralPath '+(Quote-PS $launcher)+' -Raw))) -PackageDirectory '+(Quote-PS $destination)
  $arguments='-NoProfile -WindowStyle Hidden -EncodedCommand '+[Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))
  $icon=Join-Path $destination $(if($app -eq 'Awake'){'PowerToys.Awake.exe'}else{'PowerToysIndividual.exe'})
  if($app -eq 'CommandNotFound'){$icon=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'}
  Save-Link (Join-Path (Join-Path ([Environment]::GetFolderPath('Programs')) 'PowerToys Individual') ('PowerToys Individual '+$app+'.lnk')) $app $destination $arguments ($icon+',0')
  if($app -eq 'Awake'){
   $legacy=Join-Path (Join-Path ([Environment]::GetFolderPath('Programs')) 'PowerToys Individual') 'Awake.lnk'
   if(Test-Path $legacy){$link=(New-Object -ComObject WScript.Shell).CreateShortcut($legacy);if($link.Description -eq 'PowerToys Individual Awake app shortcut' -and $link.WorkingDirectory.StartsWith((Join-Path $InstallRoot 'Awake')+'\',[StringComparison]::OrdinalIgnoreCase)){Remove-Item -LiteralPath $legacy}}
  }
  $startup= -not $NoStartup -and $app -ne 'CommandNotFound'
  if($app -eq 'Awake'){
   & ([scriptblock]::Create((Get-Content (Join-Path $destination 'Set-Startup.ps1') -Raw))) -Action $(if($startup){'Enable'}else{'Disable'}) -PackageDirectory $destination
  }else{
   $startupLink=Join-Path ([Environment]::GetFolderPath('Startup')) ('PowerToys Individual '+$app+'.lnk')
   if($startup){Save-Link $startupLink $app $destination $arguments ($icon+',0')}
   elseif(Test-Path $startupLink){Owned-Link $startupLink $app;Remove-Item -LiteralPath $startupLink}
  }
  if(-not $NoLaunch){
   # Upgrade only the owned installation recorded by this installer.
   if($previous -and $previous.path -ne $destination){
    $old=[IO.Path]::GetFullPath($previous.path)
    if($previous.app -eq $app -and $old.StartsWith($InstallRoot+'\',[StringComparison]::OrdinalIgnoreCase)){
     if($app -eq 'Awake'){Get-Process -Name PowerToys.Awake -ErrorAction SilentlyContinue | Where-Object Path -eq (Join-Path $old 'PowerToys.Awake.exe') | Stop-Process}
     elseif(@(Get-Process -Name PowerToysIndividual -ErrorAction SilentlyContinue | Where-Object Path -eq (Join-Path $old 'PowerToysIndividual.exe')).Count){& (Join-Path $old 'PowerToysIndividual.exe') --quit;Start-Sleep -Milliseconds 500}
    }
   }
   Start-Process -FilePath (Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe') -ArgumentList $arguments -WindowStyle Hidden
  }
  [ordered]@{app=$app;release=$release;architecture=$architecture;path=$destination;startup=$startup;starts_off=($app -eq 'Awake');installed_at_utc=[DateTime]::UtcNow.ToString('o')} | ConvertTo-Json | Set-Content $receiptPath -Encoding UTF8
  $key='HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\PowerToysIndividual-'+$app
  if(Test-Path $key){$existing=Get-ItemProperty $key;if(-not $existing.PowerToysIndividualOwner -or -not $existing.PowerToysIndividualOwner.StartsWith($InstallRoot+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Unrelated uninstall registration exists.'}}
  New-Item $key -Force | Out-Null
  $uninstallScript=Join-Path $destination 'Uninstall-App.ps1'
  $uninstallCode='& ([scriptblock]::Create([IO.File]::ReadAllText('+(Quote-PS $uninstallScript)+'))) -PackageDirectory '+(Quote-PS $destination)+' -ExpectedApp '+(Quote-PS $app)+' -ShowMessage'
  $uninstallArguments=' -NoProfile -EncodedCommand '+[Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($uninstallCode))
  $powershell=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
  foreach($property in @{DisplayName=('PowerToys Individual '+$app);DisplayVersion=$release.TrimStart('v');Publisher='PowerToys Individual community project';InstallLocation=$destination;DisplayIcon=($icon+',0');URLInfoAbout=('https://github.com/'+$repository);UninstallString=('"'+$powershell+'"'+$uninstallArguments);PowerToysIndividualOwner=$destination}.GetEnumerator()){New-ItemProperty $key -Name $property.Key -Value $property.Value -PropertyType String -Force | Out-Null}
  foreach($property in @('NoModify','NoRepair')){New-ItemProperty $key -Name $property -Value 1 -PropertyType DWord -Force | Out-Null}
  Write-Output "$app installed: $destination"
 }
}finally{Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue}
