module finedge.ext.connectors;

import haystack.tag;
import haystack.filter;
import std.typecons;
import std.conv;
import std.array;
import std.range;
import core.time;

export:
shared interface ConnContext
{
	@property shared(IIntegratedConnectorImpl) conn();
	@property immutable(Dict) record();
	@property immutable(TuningPolicy) tuningPolicy();
	//@property shared(TagDatabase) db();
	void * callSharedMethod(string extName, string methodName, shared(void*)[] args...);
}

shared interface ExtensionLibrary
{
	void * callFunction(string name, shared(void*)[] args...);
}

immutable struct TuningPolicy
{
	Dict record;
	string name					= "default";
	Duration pollInterval		= dur!("seconds")(1);
	Duration staleExpiration	= dur!("minutes")(5);
	Duration maxWriteInterval;
	Duration minWriteInterval;

	private this(immutable(Dict) record)
	{
		this.record	= record;
		this.name	= record.get!Str("name").val;

		if (record.has("pollTime"))
			this.pollInterval		= dur!("seconds")(cast (long) record.get!Num("pollTime").val);

		if (record.has("staleTime"))
			this.staleExpiration	= dur!("seconds")(cast (long) record.get!Num("staleTime").val);

		if (record.has("maxWriteTime"))
			this.maxWriteInterval	= dur!("seconds")(cast (long) record.get!Num("maxWriteTime").val);

		if (record.has("minWriteTime"))
			this.minWriteInterval	= dur!("seconds")(cast (long) record.get!Num("minWriteTime").val);
	}

	@property bool hasMinWrite()
	{
		return (this.minWriteInterval != Duration.init);
	}
	
	@property bool hasMaxWrite()
	{
		return (this.maxWriteInterval != Duration.init);
	}

	@property immutable(Ref) id()
	{
		if (this.record == Dict.init)
			return Ref.init;

		return this.record.id;
	}
	
	static TuningPolicy fromRec(immutable(Dict) record)
	{
		return TuningPolicy(record);
	}
}


shared abstract class ExtensionConnector
{
	protected shared(ConnContext) context;

	void setContext(shared(ConnContext) context)
	{
		this.context	= context;
	}

	abstract immutable(Dict) onOpen();
	abstract void onClose();
	abstract void onPoll();
	abstract void onWrite(shared(ConnPoint) point, Tag value, int level, string who);
	abstract immutable(Grid) onLearn(Tag token = Na());
	abstract void onPointChange(shared(ConnPoint) point, immutable(Dict) changes);
	abstract void onWatch(shared(ConnPoint)[] points);
	abstract void onUnwatch(shared(ConnPoint)[] points);
	abstract void onHouseKeeping();
	abstract void onShutdown();


	final void open()
	{
		this.context.conn.send(ConnMsg.make("open"));
	}
	
	final void openPin(string name)
	{
		this.context.conn.send(ConnMsg.make("open", Str(name).tag));
	}

	final void close()
	{
		this.context.conn.send(ConnMsg.make("close"));
	}

	final void closePin(string name)
	{
		this.context.conn.send(ConnMsg.make("close", Str(name).tag));
	}
}

shared interface IIntegratedConnectorImpl
{
	@property immutable(Dict) record();
	@property immutable(TuningPolicy) tuningPolicy();
	@property shared(ConnPoint)[] watchedPoints();
	@property shared(ConnPoint[Ref]) pointTable();
	@property bool isOpen();
	void send(immutable(ConnMsg) message);
	
}

shared interface ConnPoint
{
	enum Status {unknown, ok, overridden, stale, fault, down}

	@property Ref id();
	@property Status currentStatus();
	@property Status writeStatus();
	@property Tag currentValue();
	@property int currentPriority();
	@property Tag[] priorityArray();
	@property MonoTime lastReadTime();
	@property MonoTime lastWriteTime();
	@property shared(Dict) rec();
	void refreshRecord();

	void updateWriteError(Error error);
	void updateReadError(Error error);
	void updateWriteOk(immutable(Tag) value, int priority);
	void updateReadOk(immutable(Tag) value, int priority);
}

immutable class ConnMsg
{
	string name;
	Tag[] data;

	this(string name)
	{
		this.name	= name;
		this.data	= null;
	}

	this(string name, immutable(Tag)[] data)
	{
		this.name	= name;
		this.data	= data;
	}

	bool hasData()
	{
		return (this.data !is null);
	}

	public static immutable(ConnMsg) make(string name)
	{
		return new immutable ConnMsg(name);
	}


	public static immutable(ConnMsg) make(string name, immutable(Tag)[] data)
	{
		return new immutable ConnMsg(name, data);
	}

	public static immutable(ConnMsg) make(string name, immutable(Tag) data)
	{
		return new immutable ConnMsg(name, [data]);
	}
}